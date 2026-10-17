({ load: function(component) {
    var action;
    component.set('v.loading',true);
    action=component.get('c.getPropertyInvoiceTotal');
    action.setParams({propertyId:component.get('v.recordId')});
    action.setCallback(this,function(response) {
        var errors;
        if (!component.isValid()) return;
        component.set('v.loading',false);
        if(response.getState()==='SUCCESS') {component.set('v.total',response.getReturnValue());component.set('v.error',null);}
        else {errors=response.getError();component.set('v.error',errors && errors[0] ? errors[0].message : 'Nie udało się obliczyć sumy.');}
    });
    $A.enqueueAction(action);
} })
