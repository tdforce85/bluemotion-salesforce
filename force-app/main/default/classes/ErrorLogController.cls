/**
 * Apex controller for the bmcErrorDashboard LWC.
 *
 * Declared without sharing intentionally: Error_Log__c OWD is Private, so the
 * guest user has no direct record access. This controller is the explicit data
 * gateway — it reads only Is_Public__c = true records and exposes nothing else.
 * Authenticated internal users access records directly via standard Salesforce UI.
 */
public without sharing class ErrorLogController {

    @AuraEnabled(cacheable=false)
    public static List<SeveritySummary> getErrorSummary() {
        List<AggregateResult> results = [
            SELECT Severity__c sev, COUNT(Id) cnt
            FROM Error_Log__c
            WHERE Is_Public__c = true
            GROUP BY Severity__c
            ORDER BY COUNT(Id) DESC
        ];
        List<SeveritySummary> summaries = new List<SeveritySummary>();
        for (AggregateResult ar : results) {
            summaries.add(new SeveritySummary(
                (String)  ar.get('sev'),
                (Integer) ar.get('cnt')
            ));
        }
        return summaries;
    }

    @AuraEnabled(cacheable=false)
    public static List<Error_Log__c> getRecentErrors() {
        return [
            SELECT Id, Name, Severity__c, Source__c, Category__c,
                   Error_Message__c, Occurred_At__c,
                   Class_Name__c, Method_Name__c, Correlation_Id__c
            FROM Error_Log__c
            WHERE Is_Public__c = true
            ORDER BY Occurred_At__c DESC
            LIMIT 20
        ];
    }

    @AuraEnabled(cacheable=false)
    public static List<SourceSummary> getErrorsBySource() {
        List<AggregateResult> results = [
            SELECT Source__c src, COUNT(Id) cnt
            FROM Error_Log__c
            WHERE Is_Public__c = true
            GROUP BY Source__c
            ORDER BY COUNT(Id) DESC
        ];
        List<SourceSummary> summaries = new List<SourceSummary>();
        for (AggregateResult ar : results) {
            summaries.add(new SourceSummary(
                (String)  ar.get('src'),
                (Integer) ar.get('cnt')
            ));
        }
        return summaries;
    }

    public class SeveritySummary {
        @AuraEnabled public String  severity;
        @AuraEnabled public Integer count;
        public SeveritySummary(String severity, Integer count) {
            this.severity = severity;
            this.count    = count;
        }
    }

    public class SourceSummary {
        @AuraEnabled public String  source;
        @AuraEnabled public Integer count;
        public SourceSummary(String source, Integer count) {
            this.source = source;
            this.count  = count;
        }
    }
}
