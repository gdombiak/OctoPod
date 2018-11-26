import Intents

class IntentHandler: INExtension {
    
    override func handler(for intent: INIntent) -> Any {
        
        if intent is SetBedTempIntent {
            return SetBedTempIntentHandler()
        } else if intent is SetToolTempIntent {
            return SetToolTempIntentHandler()
        } else if intent is PauseJobIntent {
            return PauseJobIntentHandler()
        } else if intent is ResumeJobIntent {
            return ResumeJobIntentHandler()
        } else if intent is CancelJobIntent {
            return CancelJobIntentHandler()
        } else if intent is RestartJobIntent {
            return RestartJobIntentHandler()
        } else if intent is RemainingTimeIntent {
            return RemainingTimeIntentHandler()
        } else {
            fatalError("Unhandled intent type: \(intent)")
        }
    }
    
}
