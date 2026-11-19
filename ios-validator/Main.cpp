#include "../source/PluginTests.h"
#include <juce_gui_basics/juce_gui_basics.h>

namespace
{
    juce::File reportFile()
    {
        return juce::File::getSpecialLocation (juce::File::userDocumentsDirectory)
            .getChildFile ("pluginval-result.json");
    }

    struct ReportingRunner final : juce::UnitTestRunner
    {
        void logMessage (const juce::String& message) override
        {
            if (message.isNotEmpty())
                log.add (message);
        }

        juce::StringArray log;
    };

    void writeReport (const juce::String& target, const juce::String& runId,
                      ReportingRunner& runner, const juce::String& error)
    {
        juce::Array<juce::var> tests;
        int failures = 0;
        bool processedAudio = false;

        for (int index = 0; index < runner.getNumResults(); ++index)
        {
            const auto& result = *runner.getResult (index);
            auto test = std::make_unique<juce::DynamicObject>();
            test->setProperty ("name", result.subcategoryName);
            test->setProperty ("passes", result.passes);
            test->setProperty ("failures", result.failures);
            tests.add (juce::var (test.release()));
            failures += result.failures;
            processedAudio |= result.subcategoryName == "Audio processing" && result.passes > 0;
        }

        auto report = std::make_unique<juce::DynamicObject>();
        report->setProperty ("target", target);
        report->setProperty ("run_id", runId);
        report->setProperty ("passed", error.isEmpty() && failures == 0 && processedAudio);
        report->setProperty ("error", error);
        report->setProperty ("tests", juce::var (tests));
        report->setProperty ("log", runner.log.joinIntoString ("\n"));
        if (! reportFile().replaceWithText (juce::JSON::toString (juce::var (report.release()))))
            juce::Logger::writeToLog ("Could not write the pluginval result.");
    }

    void validate (const juce::String& target, const juce::String& runId)
    {
        ReportingRunner runner;
        runner.setAssertOnFailure (false);
        runner.setPassesAreLogged (false);

        if (! target.startsWith ("AudioUnit:"))
        {
            writeReport (target, runId, runner, "Pass a registered AudioUnit: selector as the app argument.");
            return;
        }

        juce::String error;
        try
        {
            PluginTests::Options options;
            options.strictnessLevel = 3;
            options.withGUI = false;
            options.randomSeed = 1;
            options.sampleRates = { 44100.0, 48000.0 };
            options.blockSizes = { 64, 512 };

            PluginTests tests (target, options);
            runner.runTests ({ &tests }, options.randomSeed);
        }
        catch (const std::exception& exception)
        {
            error = juce::String::fromUTF8 (exception.what());
        }
        catch (...)
        {
            error = "Validation raised an unknown exception.";
        }
        writeReport (target, runId, runner, error);
    }

    class StatusWindow final : public juce::DocumentWindow,
                               private juce::Timer
    {
    public:
        StatusWindow()
            : DocumentWindow ("pluginval iOS", juce::Colours::black, 0)
        {
            status.setJustificationType (juce::Justification::centred);
            status.setText ("Running AUv3 validation…", juce::dontSendNotification);
            setContentNonOwned (&status, false);
            setFullScreen (true);
            setVisible (true);
            startTimer (250);
        }

        ~StatusWindow() override { clearContentComponent(); }

    private:
        void timerCallback() override
        {
            if (reportFile().existsAsFile())
            {
                const auto result = juce::JSON::parse (reportFile());
                if (auto* object = result.getDynamicObject())
                    status.setText (static_cast<bool> (object->getProperty ("passed"))
                                        ? "AUv3 validation passed" : "AUv3 validation failed",
                                    juce::dontSendNotification);
                stopTimer();
            }
        }

        juce::Label status;
    };

    class Application final : public juce::JUCEApplication
    {
    public:
        const juce::String getApplicationName() override { return "pluginval iOS"; }
        const juce::String getApplicationVersion() override { return PLUGINVAL_IOS_VERSION; }

        void initialise (const juce::String& commandLine) override
        {
            reportFile().deleteFile();
            window = std::make_unique<StatusWindow>();
            const auto target = commandLine.trim().unquoted();
            const auto runId = juce::SystemStats::getEnvironmentVariable ("PLUGINVAL_RUN_ID", {});
            if (! juce::Thread::launch ([target, runId] { validate (target, runId); }))
            {
                ReportingRunner runner;
                writeReport (target, runId, runner, "Could not start the validation worker.");
            }
        }

        void shutdown() override { window.reset(); }

    private:
        std::unique_ptr<StatusWindow> window;
    };
}

START_JUCE_APPLICATION (Application)
