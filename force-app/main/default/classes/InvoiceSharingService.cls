/** Lab 7.3. Trigger-owned, read-only Apex managed sharing.
 * Synchronizes only Selected_User__c rows; manual/rule/owner shares stay untouched.
 * The caller must already be authorized to edit the invoice and Shared_With__c.
 */
public without sharing class InvoiceSharingService {
    public static void synchronize(List<Invoice__c> invoices, Map<Id, Invoice__c> previous) {
        Map<Id, Id> recipients = new Map<Id, Id>();
        for (Invoice__c invoice : invoices) {
            if (invoice.Id == null || invoice.hasErrors()) continue;
            Invoice__c old = previous == null ? null : previous.get(invoice.Id);
            // Most invoices have no selected recipient: preserve the one-query tax path.
            if (invoice.Shared_With__c == null && (old == null || old.Shared_With__c == null)) continue;
            recipients.put(invoice.Id, invoice.Shared_With__c == invoice.OwnerId ? null : invoice.Shared_With__c);
        }
        if (recipients.isEmpty()) return;
        List<Invoice__Share> obsolete = new List<Invoice__Share>();
        Set<Id> alreadyShared = new Set<Id>();
        Set<Id> invoiceIds = recipients.keySet();
        for (Invoice__Share grant : [
            SELECT Id, ParentId, UserOrGroupId, AccessLevel FROM Invoice__Share
            WHERE ParentId IN :invoiceIds AND RowCause = 'Selected_User__c' WITH SYSTEM_MODE
        ]) {
            if (recipients.get(grant.ParentId) == grant.UserOrGroupId && grant.AccessLevel == 'Read') {
                alreadyShared.add(grant.ParentId);
            } else {
                obsolete.add(grant);
            }
        }
        if (!obsolete.isEmpty()) Database.delete(obsolete, AccessLevel.SYSTEM_MODE);
        List<Invoice__Share> missing = new List<Invoice__Share>();
        for (Id invoiceId : recipients.keySet()) {
            Id recipient = recipients.get(invoiceId);
            if (recipient == null || alreadyShared.contains(invoiceId)) continue;
            missing.add(new Invoice__Share(ParentId=invoiceId, UserOrGroupId=recipient,
                AccessLevel='Read', RowCause=Schema.Invoice__Share.RowCause.Selected_User__c));
        }
        // An invoice edit must roll back if its promised share cannot be applied.
        if (!missing.isEmpty()) Database.insert(missing, AccessLevel.SYSTEM_MODE);
    }
}
