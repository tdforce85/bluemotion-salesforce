/**
 * Unified error logging service. Dual-writes to Error_Log__c and publishes Error_Event__e.
 *
 * Declared without sharing so the insert succeeds regardless of running user context
 * (guest users, triggers, queueables). Uses AccessLevel.SYSTEM_MODE to bypass CRUD/FLS —
 * error logging is a system concern and must never be blocked by the caller's permissions.
 *
 * Usage:
 *   ErrorLogger.create()
 *       .source(ErrorLogger.Source.LWC)
 *       .category(ErrorLogger.Category.DML)
 *       .severity(ErrorLogger.Severity.HIGH)
 *       .className('MyController')
 *       .methodName('doSomething')
 *       .objectName('Lead')
 *       .message('Insert failed: ' + e.getMessage())
 *       .log();
 */
public without sharing class ErrorLogger {

    public enum Source   { APEX_TRIGGER, FLOW, PLATFORM_EVENT, LWC, QUEUEABLE, BATCH_APEX }
    public enum Category { VALIDATION, DML, INTEGRATION, SECURITY, GOVERNOR_LIMIT, BUSINESS_RULE, CALLOUT }
    public enum Severity { CRITICAL, HIGH, MEDIUM, LOW, INFO }

    private static String currentCorrelationId;

    public static String getCorrelationId() {
        if (currentCorrelationId == null) {
            currentCorrelationId = generateUUID();
        }
        return currentCorrelationId;
    }

    public static Builder create() {
        return new Builder();
    }

    public class Builder {
        private Source   src;
        private Category cat;
        private Severity sev;
        private String   msg;
        private String   cls;
        private String   mth;
        private String   obj;
        private String   recId;

        public Builder source(Source s)    { this.src   = s;    return this; }
        public Builder category(Category c){ this.cat   = c;    return this; }
        public Builder severity(Severity s){ this.sev   = s;    return this; }
        public Builder message(String m)   { this.msg   = m;    return this; }
        public Builder className(String c) { this.cls   = c;    return this; }
        public Builder methodName(String m){ this.mth   = m;    return this; }
        public Builder objectName(String o){ this.obj   = o;    return this; }
        public Builder recordId(String r)  { this.recId = r;    return this; }

        public void log() {
            ErrorLogger.writeLog(this);
        }
    }

    private static void writeLog(Builder b) {
        String   corrId = getCorrelationId();
        DateTime now    = System.now();

        Error_Log__c logRecord = new Error_Log__c(
            Correlation_Id__c  = corrId,
            Source__c          = sourceLabel(b.src),
            Category__c        = categoryLabel(b.cat),
            Severity__c        = severityLabel(b.sev),
            Error_Message__c   = b.msg,
            Class_Name__c      = b.cls,
            Method_Name__c     = b.mth,
            Object_API_Name__c = b.obj,
            Record_Id__c       = b.recId,
            Occurred_At__c     = now,
            Is_Public__c       = true
        );

        Error_Event__e evt = new Error_Event__e(
            Correlation_Id__c  = corrId,
            Source__c          = sourceLabel(b.src),
            Category__c        = categoryLabel(b.cat),
            Severity__c        = severityLabel(b.sev),
            Error_Message__c   = b.msg,
            Class_Name__c      = b.cls,
            Method_Name__c     = b.mth,
            Object_API_Name__c = b.obj,
            Record_Id__c       = b.recId,
            Occurred_At__c     = now
        );

        try {
            // SYSTEM_MODE bypasses CRUD/FLS — intentional, logging must always succeed
            Database.insert(logRecord, AccessLevel.SYSTEM_MODE);
            EventBus.publish(evt);
        } catch (Exception e) {
            // Cannot use ErrorLogger to log its own failure — fallback to debug only
            System.debug(LoggingLevel.ERROR, 'ErrorLogger.writeLog failed: ' + e.getMessage());
        }
    }

    private static String sourceLabel(Source s) {
        if (s == null) return null;
        switch on s {
            when APEX_TRIGGER   { return 'Apex Trigger'; }
            when FLOW           { return 'Flow'; }
            when PLATFORM_EVENT { return 'Platform Event'; }
            when LWC            { return 'LWC'; }
            when QUEUEABLE      { return 'Queueable'; }
            when BATCH_APEX     { return 'Batch Apex'; }
            when else           { return null; }
        }
    }

    private static String categoryLabel(Category c) {
        if (c == null) return null;
        switch on c {
            when VALIDATION     { return 'Validation'; }
            when DML            { return 'DML'; }
            when INTEGRATION    { return 'Integration'; }
            when SECURITY       { return 'Security'; }
            when GOVERNOR_LIMIT { return 'Governor Limit'; }
            when BUSINESS_RULE  { return 'Business Rule'; }
            when CALLOUT        { return 'Callout'; }
            when else           { return null; }
        }
    }

    private static String severityLabel(Severity s) {
        if (s == null) return null;
        switch on s {
            when CRITICAL { return 'Critical'; }
            when HIGH     { return 'High'; }
            when MEDIUM   { return 'Medium'; }
            when LOW      { return 'Low'; }
            when INFO     { return 'Info'; }
            when else     { return null; }
        }
    }

    private static String generateUUID() {
        String hex = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
        return hex.substring(0,  8) + '-' +
               hex.substring(8,  12) + '-4' +
               hex.substring(13, 16) + '-' +
               hex.substring(16, 20) + '-' +
               hex.substring(20, 32);
    }
}
