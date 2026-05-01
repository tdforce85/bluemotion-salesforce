@isTest
private class OverEngineeredLeadControllerTest {
  @isTest
  static void testCreateLeadSuccessPublishesEvent() {
    Map<String, String> data = new Map<String, String>{
      'firstName' => 'Tony',
      'lastName' => 'DeGregorio',
      'email' => 'tony@bluemotion.test',
      'company' => 'Blue Motion Consulting',
      'phone' => '555-0100'
    };

    Test.startTest();
    OverEngineeredLeadController.LeadResult result = (OverEngineeredLeadController.LeadResult) OverEngineeredLeadController.createLead(
      data
    );
    Test.stopTest();

    System.assertNotEquals(null, result, 'LeadResult should not be null');
    System.assertNotEquals(null, result.leadId, 'leadId should be populated');
    System.assertEquals(
      true,
      result.eventPublished,
      'Event should have published'
    );

    List<Lead> leads = [
      SELECT LastName, Email, LeadSource
      FROM Lead
      WHERE Id = :result.leadId
    ];
    System.assertEquals(1, leads.size(), 'Lead should exist');
    System.assertEquals('Over-Engineered Web Form', leads[0].LeadSource);

    // Verify the Lead was enriched via the full event → trigger → queueable chain
    Lead enriched = [SELECT Description FROM Lead WHERE Id = :result.leadId];
    System.assert(
      String.isNotBlank(enriched.Description),
      'Lead should have been enriched by the queueable via the Platform Event chain'
    );
  }

  @isTest
  static void testCreateLeadMissingLastNameThrows() {
    Map<String, String> data = new Map<String, String>{
      'firstName' => 'No',
      'company' => 'Some Co'
    };
    try {
      OverEngineeredLeadController.createLead(data);
      System.assert(false, 'Should have thrown AuraHandledException');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('LastName') ||
        e.getMessage().contains('obviously'),
        'Exception should reference LastName requirement'
      );
    }
  }

  @isTest
  static void testCreateLeadMissingCompanyThrows() {
    Map<String, String> data = new Map<String, String>{
      'lastName' => 'NoCompany',
      'email' => 'no@company.test'
    };
    try {
      OverEngineeredLeadController.createLead(data);
      System.assert(false, 'Should have thrown AuraHandledException');
    } catch (AuraHandledException e) {
      System.assert(
        e.getMessage().contains('Company') ||
        e.getMessage().contains('invoice'),
        'Exception should reference Company requirement'
      );
    }
  }

  @isTest
  static void testCreateLeadNullDataThrows() {
    try {
      OverEngineeredLeadController.createLead(null);
      System.assert(false, 'Should have thrown AuraHandledException');
    } catch (AuraHandledException e) {
      System.assert(true, 'Null leadData should throw');
    }
  }

  @isTest
  static void testCheckForDuplicatesFindsMatch() {
    Lead existing = new Lead(
      FirstName = 'Dupe',
      LastName = 'Check',
      Email = 'dupe@check.test',
      Company = 'Dupe Co'
    );
    insert existing;

    Test.startTest();
    List<Lead> dupes = OverEngineeredLeadController.checkForDuplicates(
      'dupe@check.test',
      'Dupe',
      'Check'
    );
    Test.stopTest();

    System.assert(dupes.size() > 0, 'Should find at least one duplicate');
    System.assertEquals(
      existing.Id,
      dupes[0].Id,
      'Should return the existing Lead'
    );
  }

  @isTest
  static void testCheckForDuplicatesBlankEmailReturnsEmpty() {
    List<Lead> result = OverEngineeredLeadController.checkForDuplicates(
      '',
      'Any',
      'Name'
    );
    System.assertEquals(
      0,
      result.size(),
      'Blank email should return empty list'
    );
  }

  @isTest
  static void testGetPlatformFeatureCountReturns42() {
    Integer count = OverEngineeredLeadController.getPlatformFeatureCount();
    System.assertEquals(
      42,
      count,
      'Feature count should be 42 (the answer to everything)'
    );
  }

  @isTest
  static void testValidationRuleErrorSurfacesCleanly() {
    // Validation rule fires when LeadSource='Over-Engineered Web Form' AND Email AND Phone are blank
    // The controller always sets Email from leadData, so trigger this by passing empty email+phone
    Map<String, String> data = new Map<String, String>{
      'lastName' => 'ValidationTest',
      'company' => 'Test Co',
      'email' => '', // blank
      'phone' => '' // blank
    };
    try {
      OverEngineeredLeadController.createLead(data);
      System.assert(false, 'Validation rule should have blocked this insert');
    } catch (AuraHandledException e) {
      // The error message should be the clean validation rule text, not a raw DmlException dump
      System.assert(
        String.isNotBlank(e.getMessage()),
        'A clean error message should be returned'
      );
    }
  }
}
