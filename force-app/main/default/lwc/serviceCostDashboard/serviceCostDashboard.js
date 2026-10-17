import { LightningElement, api, wire } from 'lwc';
import getCosts from '@salesforce/apex/ServiceCostController.getCosts';
export default class ServiceCostDashboard extends LightningElement {
    @api recordId = null;
    @api providerId = null;
    rows = [];
    loading = true;
    error;
    truncated = false;
    currencyCode;
    @wire(getCosts, { propertyId: '$recordId', providerId: '$providerId' })
    costs({ data, error }) {
        this.loading = false;
        if (data) {
            this.rows = data.rows;
            this.truncated = data.truncated;
            this.currencyCode = data.currencyCode;
            this.error = undefined;
        } else if (error) {
            this.rows = [];
            this.truncated = false;
            this.error = error.body?.message || 'Nie udało się odczytać kosztów.';
        }
    }
    get hasRows() { return this.rows.length > 0; }
    get ready() { return !this.loading && !this.error; }
}
