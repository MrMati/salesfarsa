// Check whether Apex supports the self-referencing property shown in PDF p. 30.
class PropertyProbe {
    public String publicProperty {
        get { return publicProperty; }
        set { publicProperty = value; }
    }
}
PropertyProbe example = new PropertyProbe();
example.publicProperty = 'hello';
Assert.areEqual('hello', example.publicProperty);
System.debug('PROPERTY_PROBE_OK');
