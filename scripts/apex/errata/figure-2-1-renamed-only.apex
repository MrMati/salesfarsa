// PDF p. 30 algorithm with only the reserved variable renamed; still incorrect.
List<Integer> numbers = new List<Integer>{1, 4, 9};
Integer lowestNumber;
Integer highestNumber;
for (Integer item : numbers) {
    if (item > highestNumber) highestNumber = item;
    if (item < lowestNumber) lowestNumber = item;
}
System.debug('EXTREMA=' + highestNumber + ',' + lowestNumber);
Integer difference = highestNumber - lowestNumber;
System.debug(difference);
