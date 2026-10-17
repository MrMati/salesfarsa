/** Corrected PDF figure 2.1 and executable examples for errata. */
public with sharing class Lab2Examples {
    public class InputException extends Exception {}
    public String publicProperty { get; set; }
    public static final Decimal US_TAX_RATE_FRACTION = 0.2;
    public static Long findHighestDifference(List<Integer> values) {
        if (values == null || values.isEmpty()) throw new InputException('A nonempty list is required.');
        Integer smallest = values[0];
        Integer largest = values[0];
        for (Integer item : values) {
            if (item == null) throw new InputException('Null elements are not allowed.');
            if (item < smallest) smallest = item;
            if (item > largest) largest = item;
        }
        // Long also handles the difference between Integer.MIN_VALUE and MAX_VALUE.
        return Long.valueOf(String.valueOf(largest)) - Long.valueOf(String.valueOf(smallest));
    }
}
