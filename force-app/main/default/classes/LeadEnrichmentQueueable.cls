public with sharing class LeadEnrichmentQueueable implements Queueable {

    private final Set<Id> leadIds;

    public LeadEnrichmentQueueable(Set<Id> leadIds) {
        this.leadIds = leadIds;
    }

    public void execute(QueueableContext ctx) {
        if (leadIds == null || leadIds.isEmpty()) {
            return;
        }

        List<Lead> leads;
        try {
            leads = [
                SELECT Id, Description
                FROM Lead
                WHERE Id IN :leadIds
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception e) {
            ErrorLogger.create()
                .source(ErrorLogger.Source.QUEUEABLE)
                .category(ErrorLogger.Category.DML)
                .severity(ErrorLogger.Severity.HIGH)
                .className('LeadEnrichmentQueueable')
                .methodName('execute')
                .objectName('Lead')
                .message('Query failed: ' + e.getMessage())
                .log();
            return;
        }

        for (Lead l : leads) {
            String tag = '[Enriched via LeadEnrichmentQueueable — ' + System.now() + ']';
            l.Description = String.isNotBlank(l.Description)
                ? tag + '\n' + l.Description
                : tag;
        }

        List<Database.SaveResult> results = Database.update(leads, false);
        for (Integer i = 0; i < results.size(); i++) {
            if (!results[i].isSuccess()) {
                ErrorLogger.create()
                    .source(ErrorLogger.Source.QUEUEABLE)
                    .category(ErrorLogger.Category.DML)
                    .severity(ErrorLogger.Severity.MEDIUM)
                    .className('LeadEnrichmentQueueable')
                    .methodName('execute')
                    .objectName('Lead')
                    .recordId(String.valueOf(leads[i].Id))
                    .message('Update failed: ' + results[i].getErrors()[0].getMessage())
                    .log();
            }
        }
    }
}
