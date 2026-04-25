/**
 * @description Over-Engineered Lead Controller — guest-callable from Experience Cloud.
 *
 * Sharing model: outer class is `with sharing` so DML (createLead) runs as the guest user.
 * Cross-account Lead reads (duplicate detection) require `without sharing` because guest
 * profiles cannot see existing Lead records, so that one query lives in an inner class.
 */
public with sharing class OverEngineeredLeadController {

    @AuraEnabled(cacheable=false)
    public static List<Lead> checkForDuplicates(String email, String firstName, String lastName) {
        if (String.isBlank(email)) {
            return new List<Lead>();
        }
        return new DuplicateFinder().findByEmailOrName(email, firstName, lastName);
    }

    @AuraEnabled
    public static String createLead(Map<String, String> leadData) {
        if (leadData == null || String.isBlank(leadData.get('lastName'))) {
            throw new AuraHandledException('LastName is required (obviously)');
        }
        if (String.isBlank(leadData.get('company'))) {
            throw new AuraHandledException('Company is required (we need to know who to invoice)');
        }

        if (!Schema.sObjectType.Lead.isCreateable()
            || !Schema.sObjectType.Lead.fields.LastName.isCreateable()
            || !Schema.sObjectType.Lead.fields.Email.isCreateable()
            || !Schema.sObjectType.Lead.fields.Company.isCreateable()) {
            throw new AuraHandledException('You do not have permission to create Leads.');
        }

        Lead newLead = new Lead(
            FirstName  = leadData.get('firstName'),
            LastName   = leadData.get('lastName'),
            Email      = leadData.get('email'),
            Company    = leadData.get('company'),
            Phone      = leadData.get('phone'),
            LeadSource = 'Over-Engineered Web Form',
            Status     = 'Open - Not Contacted'
        );

        Database.SaveResult result = Database.insert(newLead, true);
        if (result.isSuccess()) {
            return result.getId();
        }
        String errorMsg = 'Lead creation failed: ';
        for (Database.Error err : result.getErrors()) {
            errorMsg += err.getMessage() + ' ';
        }
        throw new AuraHandledException(errorMsg);
    }

    @AuraEnabled(cacheable=true)
    public static Integer getPlatformFeatureCount() {
        return 42;
    }

    /**
     * Elevated read for duplicate detection. Guest users cannot see existing Leads
     * under sharing rules, so this inner class runs `without sharing`. Only the
     * minimal fields needed to render the UI warning are returned.
     */
    private without sharing class DuplicateFinder {
        List<Lead> findByEmailOrName(String email, String firstName, String lastName) {
            String soql = 'SELECT Id, FirstName, LastName, Email FROM Lead WHERE Email = :email';
            Map<String, Object> binds = new Map<String, Object>{ 'email' => email };

            if (String.isNotBlank(firstName) && String.isNotBlank(lastName)) {
                soql += ' OR (FirstName = :firstName AND LastName = :lastName)';
                binds.put('firstName', firstName);
                binds.put('lastName', lastName);
            }
            soql += ' ORDER BY CreatedDate DESC LIMIT 10';

            return Database.queryWithBinds(soql, binds, AccessLevel.SYSTEM_MODE);
        }
    }
}
