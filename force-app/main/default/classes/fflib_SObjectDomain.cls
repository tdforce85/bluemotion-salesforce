// Sourced from fflib-apex-common (MIT License). Inlined to avoid package dependency on Developer Edition.
// https://github.com/apex-enterprise-patterns/fflib-apex-common
public virtual class fflib_SObjectDomain implements fflib_ISObjectDomain {
  public List<SObject> Records { get; private set; }
  public Schema.DescribeSObjectResult SObjectDescribe { get; private set; }

  public fflib_SObjectDomain(List<SObject> sObjectList) {
    Records = sObjectList;
    SObjectDescribe = sObjectList.getSObjectType().getDescribe();
  }

  public virtual void onBeforeInsert() {
  }
  public virtual void onAfterInsert() {
  }
  public virtual void onBeforeUpdate(Map<Id, SObject> existingRecords) {
  }
  public virtual void onAfterUpdate(Map<Id, SObject> existingRecords) {
  }
  public virtual void onBeforeDelete() {
  }
  public virtual void onAfterDelete() {
  }
  public virtual void onAfterUndelete() {
  }

  public void handleBeforeInsert() {
    onBeforeInsert();
  }
  public void handleAfterInsert() {
    onAfterInsert();
  }
  public void handleBeforeUpdate(Map<Id, SObject> existingRecords) {
    onBeforeUpdate(existingRecords);
  }
  public void handleAfterUpdate(Map<Id, SObject> existingRecords) {
    onAfterUpdate(existingRecords);
  }
  public void handleBeforeDelete() {
    onBeforeDelete();
  }
  public void handleAfterDelete() {
    onAfterDelete();
  }
  public void handleAfterUndelete() {
    onAfterUndelete();
  }

  public static void triggerHandler(Type domainClass) {
    IConstructable domainConstructor = (IConstructable) Type.forName(
        domainClass.getName() + '.Constructor'
      )
      .newInstance();

    if (Trigger.isBefore) {
      if (Trigger.isInsert) {
        domainConstructor.construct(Trigger.new).handleBeforeInsert();
      } else if (Trigger.isUpdate) {
        domainConstructor.construct(Trigger.new)
          .handleBeforeUpdate(Trigger.oldMap);
      } else if (Trigger.isDelete) {
        domainConstructor.construct(Trigger.old).handleBeforeDelete();
      }
    } else if (Trigger.isAfter) {
      if (Trigger.isInsert) {
        domainConstructor.construct(Trigger.new).handleAfterInsert();
      } else if (Trigger.isUpdate) {
        domainConstructor.construct(Trigger.new)
          .handleAfterUpdate(Trigger.oldMap);
      } else if (Trigger.isDelete) {
        domainConstructor.construct(Trigger.old).handleAfterDelete();
      } else if (Trigger.isUndelete) {
        domainConstructor.construct(Trigger.new).handleAfterUndelete();
      }
    }
  }

  public interface IConstructable {
    fflib_SObjectDomain construct(List<SObject> sObjectList);
  }
}
