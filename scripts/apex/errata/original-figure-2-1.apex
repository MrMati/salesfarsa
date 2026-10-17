// Original algorithm from PDF p. 30; intentionally incorrect for reproduction.
List<Integer> numbers = new List<Integer>{1, 4, 9};
Integer lowestNumber;
Integer highestNumber;
for (Integer number : numbers) {
    if (number > highestNumber) highestNumber = number;
    if (number < lowestNumber) lowestNumber = number;
}
System.debug('EXTREMA=' + highestNumber + ',' + lowestNumber);
Integer difference = highestNumber - lowestNumber;
System.debug(difference);
