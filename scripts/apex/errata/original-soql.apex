// Original SOQL from PDF p. 35; supported syntax confirmed by execution.
List<Account> records = [SELECT Id, (SELECT Contact.Name FROM Account.Contacts) FROM Account];
