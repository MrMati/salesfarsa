public with sharing class QuoteMatchAction {
    public class Input {
        @InvocableVariable(required=true) public Id serviceId;
        @InvocableVariable(required=true) public Datetime startAt;
        @InvocableVariable(required=true) public Datetime endAt;
    }
    public class Output {
        @InvocableVariable public Id providerId;
        @InvocableVariable public String status;
        @InvocableVariable public String explanation;
    }
    @InvocableMethod(label='Dopasuj wykonawcę: kwalifikacje i dostępność')
    public static List<Output> match(List<Input> inputs) {
        List<BookingEligibility.Request> requests=new List<BookingEligibility.Request>();
        for(Input input:inputs) requests.add(new BookingEligibility.Request(input.serviceId,input.startAt,input.endAt));
        List<List<BookingEligibility.ProviderOption>> options=BookingEligibility.findProviders(requests,null);
        List<Output> outputs=new List<Output>();
        for(List<BookingEligibility.ProviderOption> candidates:options) {
            Output value=new Output();
            if(candidates.isEmpty()) {value.status='Unmatched';value.explanation='Brak aktywnej, dostępnej firmy z kompletem kwalifikacji.';}
            else {value.providerId=candidates[0].value;value.status='Assigned';value.explanation='Dopasowano: '+candidates[0].label+'. Wybór alfabetyczny; zapytanie nie rezerwuje terminu.';}
            outputs.add(value);
        }
        return outputs;
    }
}
