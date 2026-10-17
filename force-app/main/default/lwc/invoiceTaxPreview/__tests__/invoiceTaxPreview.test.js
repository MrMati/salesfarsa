import { createElement } from 'lwc';
import InvoiceTaxPreview from 'c/invoiceTaxPreview';
import getPreview from '@salesforce/apex/InvoiceLabController.getPreview';
jest.mock('@salesforce/apex/InvoiceLabController.getPreview', () => {
    const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
    return { default: createApexTestWireAdapter(jest.fn()) };
}, { virtual:true });
const flush=()=>Promise.resolve();
const context={amount:100,country:'PL',rates:[{country:'PL',rate:23},{country:'DE',rate:19}]};
afterEach(()=>{document.body.replaceChildren();jest.clearAllMocks();});
function mount() {const el=createElement('c-invoice-tax-preview',{is:InvoiceTaxPreview});el.recordId='a03000000000001AAA';document.body.appendChild(el);return el;}
test('country selection recalculates preview without saving invoice',async()=>{
    const el=mount();getPreview.emit(context);await flush();
    const tax=()=>el.shadowRoot.querySelector('[data-testid="tax"] lightning-formatted-number').value;
    expect(tax()).toBe(23);
    const choice=el.shadowRoot.querySelector('lightning-combobox');choice.dispatchEvent(new CustomEvent('change',{detail:{value:'DE'}}));await flush();
    expect(tax()).toBe(19);
    expect(getPreview.getLastConfig()).toEqual({invoiceId:'a03000000000001AAA'});
});
test('HALF_UP preview rounds half cent to 0.12 and supports zero rate',async()=>{
    const el=mount();getPreview.emit({...context,amount:0.5,rates:[{country:'PL',rate:23},{country:'DE',rate:0}]});await flush();
    expect(el.shadowRoot.querySelector('[data-testid="tax"] lightning-formatted-number').value).toBe(0.12);
    el.shadowRoot.querySelector('lightning-combobox').dispatchEvent(new CustomEvent('change',{detail:{value:'DE'}}));await flush();
    expect(el.shadowRoot.querySelector('[data-testid="tax"] lightning-formatted-number').value).toBe(0);
});
test('loading and backend configuration errors are visible',async()=>{
    const el=mount();expect(el.shadowRoot.querySelector('lightning-spinner')).not.toBeNull();
    getPreview.error({message:'Powielona konfiguracja stawki.'});await flush();
    expect(el.shadowRoot.querySelector('[role="alert"]').textContent).toContain('Powielona konfiguracja');
    expect(el.shadowRoot.querySelector('lightning-combobox')).toBeNull();
});
