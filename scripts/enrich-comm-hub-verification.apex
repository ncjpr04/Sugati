CommHubRecipientVerificationSeeder.SeedResponse response =
    CommHubRecipientVerificationSeeder.enrichExistingVerificationOpps();
System.debug('=== Comm Hub Verification Enrich Complete ===');
for (CommHubRecipientVerificationSeeder.SeedResult row : response.results) {
    System.debug(row.scenario + ' | OppId=' + row.opportunityId + ' | ' + row.notes);
}
if (!response.errors.isEmpty()) {
    System.debug('Errors: ' + response.errors);
}
