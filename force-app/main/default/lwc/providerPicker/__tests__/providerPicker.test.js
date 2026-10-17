import { createElement } from 'lwc';
import ProviderPicker from 'c/providerPicker';
import getAvailableProviders from '@salesforce/apex/InvoiceLabController.getAvailableProviders';
jest.mock('@salesforce/apex/InvoiceLabController.getAvailableProviders',()=>({default:jest.fn()}),{virtual:true});
const flush=async()=>{await Promise.resolve();await Promise.resolve();await Promise.resolve();};
afterEach(()=>{document.body.replaceChildren();jest.clearAllMocks();});
function mount() {const el=createElement('c-provider-picker',{is:ProviderPicker});el.serviceId='service';el.startAt='2030-01-15T08:00:00Z';el.endAt='2030-01-15T10:00:00Z';document.body.appendChild(el);return el;}
test('requires selection and notifies Flow about chosen provider',async()=>{
    getAvailableProviders.mockResolvedValue([{label:'Firma A',value:'accountA'}]);const el=mount();await flush();
    expect(el.validate().isValid).toBe(false);
    const changed=jest.fn();el.addEventListener('lightning__flowattributechange',changed);
    el.shadowRoot.querySelector('lightning-combobox').dispatchEvent(new CustomEvent('change',{detail:{value:'accountA'}}));await flush();
    expect(el.validate().isValid).toBe(true);
    expect(changed).toHaveBeenCalledTimes(1);
    expect(el.providerId).toBe('accountA');
    expect(getAvailableProviders).toHaveBeenCalledWith({serviceId:'service',startAt:'2030-01-15T08:00:00Z',endAt:'2030-01-15T10:00:00Z'});
});
test('refresh removes stale selection and prevents Next',async()=>{
    getAvailableProviders.mockResolvedValueOnce([{label:'Firma A',value:'accountA'}]).mockResolvedValueOnce([]);
    const el=mount();await flush();el.shadowRoot.querySelector('lightning-combobox').dispatchEvent(new CustomEvent('change',{detail:{value:'accountA'}}));await flush();
    expect(el.validate().isValid).toBe(true);
    el.shadowRoot.querySelector('lightning-button').click();await flush();
    expect(el.validate().isValid).toBe(false);expect(el.shadowRoot.querySelector('[role="status"]').textContent).toContain('Brak dostępnych firm');
});
test('backend failure is explained and cannot be submitted',async()=>{
    getAvailableProviders.mockRejectedValue({body:{message:'Brak dostępu do danych.'}});const el=mount();await flush();
    expect(el.shadowRoot.querySelector('[role="alert"]').textContent).toContain('Brak dostępu');expect(el.validate().isValid).toBe(false);
});
