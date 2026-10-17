@IsTest private class Lab2ExamplesTest {
    @IsTest static void rangeHandlesPositiveNegativeAndSingle() {
        Assert.areEqual(8L,Lab2Examples.findHighestDifference(new List<Integer>{1,4,9}));
        Assert.areEqual(8L,Lab2Examples.findHighestDifference(new List<Integer>{-9,-4,-1}));
        Assert.areEqual(0L,Lab2Examples.findHighestDifference(new List<Integer>{7}));
        Assert.areEqual(4294967295L,Lab2Examples.findHighestDifference(new List<Integer>{Integer.valueOf('-2147483648'),2147483647}));
    }
    @IsTest static void rangeRejectsInvalidInput() {
        for (List<Integer> values : new List<List<Integer>>{null,new List<Integer>(),new List<Integer>{1,null},new List<Integer>{null,1}}) {
            Boolean failed=false;
            try { Lab2Examples.findHighestDifference(values); }
            catch (Lab2Examples.InputException ex) { failed=true; }
            Assert.isTrue(failed);
        }
    }
    @IsTest static void propertyAndConstant() {
        Lab2Examples example=new Lab2Examples();example.publicProperty='OK';
        Assert.areEqual('OK',example.publicProperty);
        Assert.areEqual(0.2,Lab2Examples.US_TAX_RATE_FRACTION);
    }
}
