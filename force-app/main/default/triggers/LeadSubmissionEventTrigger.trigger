trigger LeadSubmissionEventTrigger on LeadSubmission__e (after insert) {
    fflib_SObjectDomain.triggerHandler(LeadSubmissionEventDomain.class);
}
