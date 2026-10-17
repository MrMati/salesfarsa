/** Lab 6.3: average billed gross cost per completed execution; cancelled invoices excluded.
 * All grouping keys, invoice amounts and filters are checked in USER_MODE.
 */
public with sharing class ServiceCostController {
    public class CostRow {
        @AuraEnabled public String key { get; set; }
        @AuraEnabled public Id propertyId { get; set; }
        @AuraEnabled public String propertyName { get; set; }
        @AuraEnabled public Id providerId { get; set; }
        @AuraEnabled public String providerName { get; set; }
        @AuraEnabled public String serviceName { get; set; }
        @AuraEnabled public Integer executions { get; set; }
        @AuraEnabled public Decimal averageGross { get; set; }
    }
    public class CostResult {
        @AuraEnabled public List<CostRow> rows { get; set; }
        @AuraEnabled public Boolean truncated { get; set; }
        @AuraEnabled public String currencyCode { get; set; }
    }
    @AuraEnabled(cacheable=true)
    public static CostResult getCosts(Id propertyId, Id providerId) {
        CostResult result = new CostResult();
        result.rows = new List<CostRow>();
        result.currencyCode = UserInfo.getDefaultCurrency();
        try {
            Map<String, Object> bindings = new Map<String, Object>();
            String criteria = '';
            if (propertyId != null) {
                criteria += ' AND Property__c = :propertyId';
                bindings.put('propertyId', propertyId);
            }
            if (providerId != null) {
                criteria += ' AND Provider__c = :providerId';
                bindings.put('providerId', providerId);
            }
            List<AggregateResult> groups = Database.queryWithBinds(
                'SELECT Property__c propertyKey, '
                + 'Provider__c providerKey, '
                + 'Service__c serviceKey, '
                + 'COUNT(Id) executions, AVG(Invoice__r.Gross_Amount__c) averageGross '
                + 'FROM Service_Execution__c '
                + 'WHERE Status__c = \'Completed\' AND Invoice__c != null '
                + 'AND Invoice__r.Status__c != \'Cancelled\' '
                + 'AND Property__c != null AND Provider__c != null AND Service__c != null '
                + criteria
                + ' GROUP BY Property__c, Provider__c, Service__c '
                + 'ORDER BY Property__c, Provider__c, Service__c LIMIT 201',
                bindings, AccessLevel.USER_MODE
            );
            Set<Id> propertyIds = new Set<Id>();
            Set<Id> providerIds = new Set<Id>();
            Set<Id> serviceIds = new Set<Id>();
            for (AggregateResult groupRow : groups) {
                propertyIds.add((Id)groupRow.get('propertyKey'));
                providerIds.add((Id)groupRow.get('providerKey'));
                serviceIds.add((Id)groupRow.get('serviceKey'));
            }
            Map<Id, Property__c> properties = new Map<Id, Property__c>([
                SELECT Id, Address__c FROM Property__c WHERE Id IN :propertyIds WITH USER_MODE
            ]);
            Map<Id, Account> providers = new Map<Id, Account>([
                SELECT Id, Name FROM Account WHERE Id IN :providerIds WITH USER_MODE
            ]);
            Map<Id, Service__c> services = new Map<Id, Service__c>([
                SELECT Id, Name, Title__c FROM Service__c WHERE Id IN :serviceIds WITH USER_MODE
            ]);
            result.truncated = groups.size() > 200;
            for (AggregateResult groupRow : groups) {
                if (result.rows.size() == 200) break;
                CostRow row = new CostRow();
                row.propertyId = (Id)groupRow.get('propertyKey');
                row.propertyName = properties.containsKey(row.propertyId) ? properties.get(row.propertyId).Address__c : 'Niedostępna nieruchomość';
                row.providerId = (Id)groupRow.get('providerKey');
                row.providerName = providers.containsKey(row.providerId) ? providers.get(row.providerId).Name : 'Niedostępna firma';
                Id serviceId = (Id)groupRow.get('serviceKey');
                Service__c service = services.get(serviceId);
                row.serviceName = service == null ? 'Niedostępna usługa'
                    : String.isBlank(service.Title__c) ? service.Name : service.Title__c;
                row.key = String.valueOf(row.propertyId) + ':' + row.providerId + ':' + groupRow.get('serviceKey');
                row.executions = (Integer)groupRow.get('executions');
                row.averageGross = ((Decimal)groupRow.get('averageGross')).setScale(2, RoundingMode.HALF_UP);
                result.rows.add(row);
            }
        } catch (QueryException ex) {
            throw new AuraHandledException('Brak dostępu do danych kosztów lub pól raportu. Skontaktuj się z administratorem.');
        }
        return result;
    }
}
