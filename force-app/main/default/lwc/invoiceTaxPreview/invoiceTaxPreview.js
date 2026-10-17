import { LightningElement, api, wire } from 'lwc';
import getPreview from '@salesforce/apex/InvoiceLabController.getPreview';
import currency from '@salesforce/i18n/currency';
export default class InvoiceTaxPreview extends LightningElement {
    @api recordId;
    data; selectedCountry; error; currency = currency;
    @wire(getPreview, { invoiceId: '$recordId' })
    context({ data, error }) {
        if (data) { this.data=data; this.selectedCountry=data.country; this.error=undefined; }
        if (error) { this.error=error.body?.message || error.message || 'Nie udało się odczytać stawek.'; this.data=undefined; }
    }
    get loaded() { return Boolean(this.data); }
    get options() { return (this.data?.rates || []).map(row => ({label: `${row.country} · ${row.rate}%`, value:row.country})); }
    get rate() { return this.data?.rates.find(row => row.country===this.selectedCountry)?.rate; }
    get hasRate() { return this.rate!==undefined && this.rate!==null; }
    get rateFraction() { return Number(this.rate)/100; }
    get amount() { return Number(this.data?.amount || 0); }
    get tax() { return Math.round((this.amount * Number(this.rate) / 100 + Number.EPSILON)*100)/100; }
    get gross() { return this.amount + this.tax; }
    changeCountry(event) { this.selectedCountry=event.detail.value; }
}
