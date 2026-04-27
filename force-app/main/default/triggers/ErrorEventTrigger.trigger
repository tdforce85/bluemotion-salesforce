trigger ErrorEventTrigger on Error_Event__e(after insert) {
  fflib_SObjectDomain.triggerHandler(ErrorEventDomain.class);
}
