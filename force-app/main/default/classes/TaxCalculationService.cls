/** Labs 2.1–2.4. Percent fields use percentage points in Apex: 23 means 23%.
 * Labs 3–4: insert and changes of amount/country; this is a teaching model, not a tax engine.
 * with sharing enforces record sharing; CRUD/FLS remain the caller's concern.
 */
public with sharing class TaxCalculationService {
    public static final Decimal DEFAULT_TAX_RATE = 23;
    public class TaxInputException extends Exception {}

    // Preserved solution to exercise 2.1; later exercises use configured rates.
    public static Decimal calculateFixedTax(Invoice__c invoice) {
        if (invoice == null || invoice.Amount__c == null || invoice.Amount__c < 0) {
            throw new TaxInputException('A nonnegative net amount is required.');
        }
        return (invoice.Amount__c * DEFAULT_TAX_RATE / 100).setScale(2, RoundingMode.HALF_UP);
    }

    // Exercise 2.3: query matching rates, also reusable for a singleton country set.
    public static List<Country_Tax_Rate__c> findTaxRates(Set<String> countries) {
        if (countries == null || countries.isEmpty()) return new List<Country_Tax_Rate__c>();
        return [SELECT Country__c, Tax__c FROM Country_Tax_Rate__c WHERE Country__c IN :countries];
    }

    public static void calculateTax(Invoice__c invoice) {
        if (invoice == null) throw new TaxInputException('Invoice is required.');
        calculateTaxes(new List<Invoice__c>{invoice});
    }

    public static void calculateTaxes(List<Invoice__c> invoices) {
        if (invoices == null || invoices.isEmpty()) return;
        Set<String> countries = new Set<String>();
        for (Invoice__c invoice : invoices) {
            if (invoice == null) throw new TaxInputException('Invoice list contains null.');
            if (!String.isBlank(invoice.Country__c)) countries.add(invoice.Country__c);
        }
        Map<String, Decimal> rates = new Map<String, Decimal>();
        Set<String> duplicates = new Set<String>();
        for (Country_Tax_Rate__c rate : findTaxRates(countries)) {
            if (rates.containsKey(rate.Country__c)) duplicates.add(rate.Country__c);
            rates.put(rate.Country__c, rate.Tax__c);
        }
        for (Invoice__c invoice : invoices) {
            if (invoice.Amount__c == null || invoice.Amount__c < 0) {
                invoice.addError('A nonnegative net amount is required.');
            } else if (String.isBlank(invoice.Country__c)) {
                invoice.addError('Invoice country is required.');
            } else if (duplicates.contains(invoice.Country__c)) {
                invoice.addError('Multiple tax rates configured for ' + invoice.Country__c + '.');
            } else if (!rates.containsKey(invoice.Country__c)) {
                invoice.addError('No tax rate configured for ' + invoice.Country__c + '.');
            } else {
                Decimal rate = rates.get(invoice.Country__c);
                if (rate == null || rate < 0 || rate > 100) {
                    invoice.addError('Tax rate must be between 0 and 100 percent.');
                    continue;
                }
                invoice.Tax__c = rate;
                invoice.Tax_Amount__c = (invoice.Amount__c * rate / 100).setScale(2, RoundingMode.HALF_UP);
            }
        }
    }
}
