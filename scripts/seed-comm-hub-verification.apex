CommHubRecipientVerificationSeeder.SeedResponse response = CommHubRecipientVerificationSeeder.seedAll();
System.debug('=== Comm Hub Verification Seed Complete ===');
for (CommHubRecipientVerificationSeeder.SeedResult row : response.results) {
    System.debug(
        row.scenario +
            ' | OppId=' +
            row.opportunityId +
            ' | Name=' +
            row.opportunityName +
            ' | Tag=' +
            row.expectedHubTag +
            ' | Tab=' +
            row.expectedDefaultTab +
            ' | TO=' +
            row.expectedDefaultTo
    );
    System.debug('Notes: ' + row.notes);
}
if (!response.errors.isEmpty()) {
    System.debug('Errors: ' + response.errors);
}
