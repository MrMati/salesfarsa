import { LightningElement, api } from 'lwc';
import { FlowAttributeChangeEvent } from 'lightning/flowSupport';
import getAvailableProviders from '@salesforce/apex/InvoiceLabController.getAvailableProviders';
export default class ProviderPicker extends LightningElement {
    @api serviceId;
    @api startAt;
    @api endAt;
    _providerId;
    @api get providerId() { return this._providerId; }
    set providerId(value) { this._providerId=value; }
    options=[]; loading=true; error;
    connectedCallback() { this.load(); }
    async load() {
        this.loading=true; this.error=undefined;
        try {
            this.options=await getAvailableProviders({serviceId:this.serviceId,startAt:this.startAt,endAt:this.endAt});
            if (!this.options.some(option=>option.value===this.providerId)) this.select(null);
        } catch(error) { this.options=[]; this.error=error.body?.message || error.message || 'Nie udało się sprawdzić dostępności.'; }
        finally { this.loading=false; }
    }
    get hasOptions() { return this.options.length>0; }
    change(event) { this.select(event.detail.value); }
    select(value) { this._providerId=value; this.dispatchEvent(new FlowAttributeChangeEvent('providerId',value)); }
    refresh() { this.load(); }
    @api validate() {
        return {isValid:!this.loading && Boolean(this.providerId) && this.options.some(option=>option.value===this.providerId),errorMessage:'Wybierz dostępną firmę albo wróć i zmień termin.'};
    }
}
