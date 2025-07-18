// Import standard .NET and 3CX CallFlow libraries
using CallFlow.CFD;
using CallFlow;
using MimeKit;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks.Dataflow;
using System.Threading.Tasks;
using System.Threading;
using System.Globalization;
using System;
using TCX.Configuration;

namespace onCall2
{
    // Main class implementing the call flow logic
    public class Main : ScriptBase<Main>, ICallflow, ICallflowProcessor
    {
        // Flags for tracking flow state
        private bool executionStarted;
        private bool executionFinished;
        private bool disconnectFlowPending;

        // Event pipeline and component tracking
        private BufferBlock<AbsEvent> eventBuffer;
        private int currentComponentIndex;
        private List<AbsComponent> mainFlowComponentList;
        private List<AbsComponent> disconnectFlowComponentList;
        private List<AbsComponent> errorFlowComponentList;
        private List<AbsComponent> currentFlowComponentList;

        // Managers and utilities
        private LogFormatter logFormatter;
        private TimerManager timerManager;
        private static Dictionary<string, Variable> variableMap;

        private TempWavFileManager tempWavFileManager;
        private PromptQueue promptQueue;
        private OnlineServices onlineServices;
        private OfficeHoursManager officeHoursManager;

        private CfdAppScope scope;

        // ======== Call Termination Logic =========
        private void DisconnectCallAndExitCallflow()
        {
            if (currentFlowComponentList == disconnectFlowComponentList)
                logFormatter.Trace("Callflow finished...");
            else
            {
                logFormatter.Trace("Callflow finished, disconnecting call...");
                MyCall.Terminate();
            }
        }

        // ======== Error Handling Flow Execution =========
        private async Task ExecuteErrorFlow()
        {
            if (currentFlowComponentList == errorFlowComponentList)
            {
                logFormatter.Trace("Error during error handler flow, exiting callflow...");
                DisconnectCallAndExitCallflow();
            }
            else if (currentFlowComponentList == disconnectFlowComponentList)
            {
                logFormatter.Trace("Error during disconnect handler flow, exiting callflow...");
                executionFinished = true;
            }
            else
            {
                currentFlowComponentList = errorFlowComponentList;
                currentComponentIndex = 0;

                if (errorFlowComponentList.Count > 0)
                {
                    logFormatter.Trace("Start executing error handler flow...");
                    await ProcessStart();
                }
                else
                {
                    logFormatter.Trace("Error handler flow is empty...");
                    DisconnectCallAndExitCallflow();
                }
            }
        }

        // ======== Disconnect Handler Flow Execution =========
        private async Task ExecuteDisconnectFlow()
        {
            currentFlowComponentList = disconnectFlowComponentList;
            currentComponentIndex = 0;
            disconnectFlowPending = false;

            if (disconnectFlowComponentList.Count > 0)
            {
                logFormatter.Trace("Start executing disconnect handler flow...");
                await ProcessStart();
            }
            else
            {
                logFormatter.Trace("Disconnect handler flow is empty...");
                executionFinished = true;
            }
        }

        // ======== Determines the next step based on component result =========
        private EventResults CheckEventResult(EventResults eventResult)
        {
            if (eventResult == EventResults.MoveToNextComponent &&
                ++currentComponentIndex == currentFlowComponentList.Count)
            {
                DisconnectCallAndExitCallflow();
                return EventResults.Exit;
            }
            else if (eventResult == EventResults.Exit)
                DisconnectCallAndExitCallflow();

            return eventResult;
        }

        // ======== Initializes all dynamic session and standard variables =========
        private void InitializeVariables(string callID)
        {
            // Call-level session values
            variableMap["session.ani"] = new Variable(MyCall.Caller.CallerID);
            variableMap["session.callid"] = new Variable(callID);
            variableMap["session.dnis"] = new Variable(MyCall.DN.Number);
            variableMap["session.did"] = new Variable(MyCall.Caller.CalledNumber);
            variableMap["session.audioFolder"] = new Variable(Path.Combine(RecordingManager.Instance.AudioFolder, promptQueue.ProjectAudioFolder));
            variableMap["session.transferingExtension"] = new Variable(MyCall.ReferredByDN?.Number ?? string.Empty);
            variableMap["session.forwardingExtension"] = new Variable(MyCall.OnBehalfOf?.Number ?? string.Empty);

            // System constants (recording, menus, inputs, etc.)
            variableMap["RecordResult.NothingRecorded"] = new Variable(RecordComponent.RecordResults.NothingRecorded);
            variableMap["RecordResult.StopDigit"] = new Variable(RecordComponent.RecordResults.StopDigit);
            variableMap["RecordResult.Completed"] = new Variable(RecordComponent.RecordResults.Completed);

            variableMap["MenuResult.Timeout"] = new Variable(MenuComponent.MenuResults.Timeout);
            variableMap["MenuResult.InvalidOption"] = new Variable(MenuComponent.MenuResults.InvalidOption);
            variableMap["MenuResult.ValidOption"] = new Variable(MenuComponent.MenuResults.ValidOption);

            variableMap["UserInputResult.Timeout"] = new Variable(UserInputComponent.UserInputResults.Timeout);
            variableMap["UserInputResult.InvalidDigits"] = new Variable(UserInputComponent.UserInputResults.InvalidDigits);
            variableMap["UserInputResult.ValidDigits"] = new Variable(UserInputComponent.UserInputResults.ValidDigits);

            variableMap["VoiceInputResult.Timeout"] = new Variable(VoiceInputComponent.VoiceInputResults.Timeout);
            variableMap["VoiceInputResult.InvalidInput"] = new Variable(VoiceInputComponent.VoiceInputResults.InvalidInput);
            variableMap["VoiceInputResult.ValidInput"] = new Variable(VoiceInputComponent.VoiceInputResults.ValidInput);
            variableMap["VoiceInputResult.ValidDtmfInput"] = new Variable(VoiceInputComponent.VoiceInputResults.ValidDtmfInput);
        }

        // ======== Component Flow Setup: Transfers Based on Week Modulo Logic =========
        private void InitializeComponents(ICallflow callflow, ICall myCall, string logHeader)
        {
            scope = CfdModule.Instance.CreateScope(callflow, myCall, logHeader);

            // Execute custom C# code to determine current week % 3
            var executeWeekCalc = new ExecuteCSharpCode1941501584ECCComponent("WeekCheckComponent", callflow, myCall, logHeader);
            executeWeekCalc.Parameters.Add(new CallFlow.CFD.Parameter("value", () => false));  // Dummy parameter
            mainFlowComponentList.Add(executeWeekCalc);

            // Create conditional transfer logic based on value
            ConditionalComponent weekCondition = scope.CreateComponent<ConditionalComponent>("WeekRoutingCondition");
            mainFlowComponentList.Add(weekCondition);

            // weekValue == 0 → transfer to Extension A
            weekCondition.ConditionList.Add(() => Convert.ToInt32(variableMap["weekValue"].Value) == 0);
            var branch1 = scope.CreateComponent<SequenceContainerComponent>("Branch_Week0");
            weekCondition.ContainerList.Add(branch1);
            var transfer1 = scope.CreateComponent<TransferComponent>("TransferToExtA");
            transfer1.DestinationHandler = () => "1004";
            transfer1.DelayMilliseconds = 500;
            branch1.ComponentList.Add(transfer1);

            // weekValue == 1 → transfer to Extension B
            weekCondition.ConditionList.Add(() => Convert.ToInt32(variableMap["weekValue"].Value) == 1);
            var branch2 = scope.CreateComponent<SequenceContainerComponent>("Branch_Week1");
            weekCondition.ContainerList.Add(branch2);
            var transfer2 = scope.CreateComponent<TransferComponent>("TransferToExtB");
            transfer2.DestinationHandler = () => "1006";
            transfer2.DelayMilliseconds = 500;
            branch2.ComponentList.Add(transfer2);

            // weekValue == 2 → transfer to Extension C
            weekCondition.ConditionList.Add(() => Convert.ToInt32(variableMap["weekValue"].Value) == 2);
            var branch3 = scope.CreateComponent<SequenceContainerComponent>("Branch_Week2");
            weekCondition.ContainerList.Add(branch3);
            var transfer3 = scope.CreateComponent<TransferComponent>("TransferToExtC");
            transfer3.DestinationHandler = () => "1002";
            transfer3.DelayMilliseconds = 500;
            branch3.ComponentList.Add(transfer3);

            // Fallback disconnects for main and error flows
            mainFlowComponentList.Add(scope.CreateComponent<DisconnectCallComponent>("MainDisconnect"));
            errorFlowComponentList.Add(scope.CreateComponent<DisconnectCallComponent>("ErrorDisconnect"));
        }

        // ======== Constructor to set up initial state =========
        public Main()
        {
            executionStarted = false;
            executionFinished = false;
            disconnectFlowPending = false;

            eventBuffer = new BufferBlock<AbsEvent>();
            mainFlowComponentList = new List<AbsComponent>();
            disconnectFlowComponentList = new List<AbsComponent>();
            errorFlowComponentList = new List<AbsComponent>();
            currentFlowComponentList = mainFlowComponentList;

            timerManager = new TimerManager();
            timerManager.OnTimeout += state => eventBuffer.Post(new TimeoutEvent(state));

            variableMap = new Dictionary<string, Variable>();
            onlineServices = new OnlineServices(null, null);  // TTS/STT not configured
        }

        // ======== Entry Point =========
        public override void Start()
        {
            string callID = MyCall?.Caller["chid"] ?? "Unknown";
            string logHeader = $"onCall2 - CallID {callID}";
            logFormatter = new LogFormatter(MyCall, logHeader, "Callflow");
            promptQueue = new PromptQueue(this, MyCall, "onCall2", logHeader);
            tempWavFileManager = new TempWavFileManager(logFormatter);
            officeHoursManager = new OfficeHoursManager(MyCall);

            logFormatter.Info($"ConnectionStatus: `{MyCall.Status}`");

            if (MyCall.Status == ConnectionStatus.Ringing)
                MyCall.AssureMedia().ContinueWith(_ => StartInternal(logHeader, callID));
            else
                StartInternal(logHeader, callID);
        }

        // ... (Remaining code for event handlers, flow processing, external components, etc. stays unchanged) ...

        // ======== Custom Code Component (Week Logic) =========
        public class ExecuteCSharpCode1941501584ECCComponent : ExternalCodeExecutionComponent
        {
            public List<CallFlow.CFD.Parameter> Parameters { get; } = new List<CallFlow.CFD.Parameter>();
            public ExecuteCSharpCode1941501584ECCComponent(string name, ICallflow callflow, ICall myCall, string projectName) : base(name, callflow, myCall, projectName) {}

            protected override object ExecuteCode()
            {
                return DateCheck_value(Convert.ToBoolean(Parameters[0].Value));
            }

            // Get current week number mod 3 and store in variableMap
            private object DateCheck_value(bool dummy)
            {
                int weekNumber = CultureInfo.InvariantCulture.Calendar.GetWeekOfYear(
                    DateTime.Now, CalendarWeekRule.FirstFourDayWeek, DayOfWeek.Monday);
                int value = weekNumber % 3;
                variableMap["weekValue"] = new Variable(value);
                return (value == 0, value);  // Used for flow decisions
            }
        }
    }
}

