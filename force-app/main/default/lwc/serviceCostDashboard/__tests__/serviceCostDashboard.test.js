import { createElement } from 'lwc';
import ServiceCostDashboard from 'c/serviceCostDashboard';
import getCosts from '@salesforce/apex/ServiceCostController.getCosts';
jest.mock('@salesforce/apex/ServiceCostController.getCosts', () => {
    const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
    return { default: createApexTestWireAdapter(jest.fn()) };
}, { virtual: true });
const flush = () => Promise.resolve();
afterEach(() => { while (document.body.firstChild) document.body.removeChild(document.body.firstChild); });
function mount() {
    const element = createElement('c-service-cost-dashboard', { is: ServiceCostDashboard });
    element.recordId = 'property-id';
    document.body.appendChild(element);
    return element;
}
it('shows average, sample count and overflow warning with property scope', async () => {
    const element = mount();
    getCosts.emit({ rows: [{ key: 'one', propertyName: 'Dom', providerName: 'Firma', serviceName: 'Mycie', executions: 2, averageGross: 184.5 }], currencyCode: 'PLN', truncated: true });
    await flush();
    expect(getCosts.getLastConfig().propertyId).toBe('property-id');
    expect(element.shadowRoot.querySelector('tbody').textContent).toContain('DomFirmaMycie2');
    expect(element.shadowRoot.querySelector('lightning-formatted-number').value).toBe(184.5);
    expect(element.shadowRoot.querySelector('[role="status"]').textContent).toContain('200');
});
it('explains an empty dataset', async () => {
    const element = mount();
    getCosts.emit({ rows: [], truncated: false, currencyCode: 'PLN' });
    await flush();
    expect(element.shadowRoot.textContent).toContain('Brak zakończonych');
    expect(element.shadowRoot.querySelector('table')).toBeNull();
});
it('clears old data when access is denied', async () => {
    const element = mount();
    getCosts.emit({ rows: [{ key: 'one', propertyName: 'Dom' }], truncated: false });
    await flush();
    getCosts.error({ message: 'Brak dostępu' });
    await flush();
    expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toBe('Brak dostępu');
    expect(element.shadowRoot.querySelector('table')).toBeNull();
});
