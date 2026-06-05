/**
 * Creates Opportunity + related records for manual Communication Hub recipient verification.
 * Run: CommHubRecipientVerificationSeeder.seedAll();
 * Enrich existing opps: CommHubRecipientVerificationSeeder.enrichExistingVerificationOpps();
 * Records are prefixed with "[CommHub Verify]" for easy lookup and cleanup.
 */
public with sharing class CommHubRecipientVerificationSeeder {
    public static final String PREFIX = '[CommHub Verify]';
    public static final String EXTRA_EMAIL_SUFFIX = '.extra.verify@test.com';

    /** Existing verification opps — run enrichExistingVerificationOpps() to add related records. */
    private static final Map<String, Id> EXISTING_VERIFY_OPP_IDS = new Map<String, Id>{
        'B2C Direct Client' => '006d3000006hQztAAE',
        'B2B Agency Routing' => '006d3000006hQzuAAE',
        'B2B Agent Routing' => '006d3000006hQzvAAE',
        'B2B opp with Client docs' => '006d3000006hQzwAAE',
        'Supplier-heavy trip' => '006d3000006hQzxAAE',
        'Non-travelling lead booker' => '006d3000006hQzyAAE',
        'No traveller emails' => '006d3000006hQzzAAE',
        'Agency without O_Agent_SC' => '006d3000006hR00AAE'
    };

    public class SeedResult {
        @AuraEnabled public String scenario;
        @AuraEnabled public Id opportunityId;
        @AuraEnabled public String opportunityName;
        @AuraEnabled public String expectedHubTag;
        @AuraEnabled public String expectedDefaultTab;
        @AuraEnabled public String expectedDefaultTo;
        @AuraEnabled public String notes;
    }

    public class SeedResponse {
        @AuraEnabled public List<SeedResult> results;
        @AuraEnabled public List<String> errors;
    }

    public static SeedResponse seedAll() {
        SeedResponse response = new SeedResponse();
        response.results = new List<SeedResult>();
        response.errors = new List<String>();

        String stageName = resolveStageName();
        Account sharedAccount = new Account(Name = PREFIX + ' Shared Traveller Account');
        insert sharedAccount;

        SharedSuppliers suppliers = ensureSharedSuppliers();

        try {
            response.results.add(seedB2cDirectClient(sharedAccount, stageName, suppliers));
        } catch (Exception ex) {
            response.errors.add('B2C Direct Client: ' + ex.getMessage());
        }
        try {
            response.results.add(seedB2bAgencyRouting(sharedAccount, stageName, suppliers));
        } catch (Exception ex) {
            response.errors.add('B2B Agency Routing: ' + ex.getMessage());
        }
        try {
            response.results.add(seedB2bAgentRouting(sharedAccount, stageName, suppliers));
        } catch (Exception ex) {
            response.errors.add('B2B Agent Routing: ' + ex.getMessage());
        }
        try {
            response.results.add(seedB2bOppClientDocs(sharedAccount, stageName, suppliers));
        } catch (Exception ex) {
            response.errors.add('B2B Client Docs: ' + ex.getMessage());
        }
        try {
            response.results.add(seedSupplierHeavyTrip(sharedAccount, stageName, suppliers));
        } catch (Exception ex) {
            response.errors.add('Supplier-heavy trip: ' + ex.getMessage());
        }
        try {
            response.results.add(seedNonTravellingLeadBooker(sharedAccount, stageName, suppliers));
        } catch (Exception ex) {
            response.errors.add('Non-travelling lead booker: ' + ex.getMessage());
        }
        try {
            response.results.add(seedMinimalNoTravellerEmails(sharedAccount, stageName));
        } catch (Exception ex) {
            response.errors.add('No traveller emails: ' + ex.getMessage());
        }
        try {
            response.results.add(seedAgencyNoAgentContact(sharedAccount, stageName, suppliers));
        } catch (Exception ex) {
            response.errors.add('Agency no named agent: ' + ex.getMessage());
        }

        return response;
    }

    /**
     * Adds extra travellers, agency contacts, suppliers, bookings, and cost payments
     * to the eight verification opportunities (idempotent via EXTRA_EMAIL_SUFFIX).
     */
    public static SeedResponse enrichExistingVerificationOpps() {
        SeedResponse response = new SeedResponse();
        response.results = new List<SeedResult>();
        response.errors = new List<String>();

        SharedSuppliers suppliers = ensureSharedSuppliers();
        Map<Id, Opportunity> oppsById = new Map<Id, Opportunity>([
            SELECT Id, Name, AccountId, sugati__O_Agent__c, sugati__O_Agent_SC__c, sugati__O_Lead_CG__c
            FROM Opportunity
            WHERE Id IN :EXISTING_VERIFY_OPP_IDS.values()
        ]);

        for (String scenario : EXISTING_VERIFY_OPP_IDS.keySet()) {
            Id oppId = EXISTING_VERIFY_OPP_IDS.get(scenario);
            try {
                if (!oppsById.containsKey(oppId)) {
                    response.errors.add(scenario + ': Opportunity not found (' + oppId + ')');
                    continue;
                }
                enrichScenario(scenario, oppsById.get(oppId), suppliers);
                SeedResult row = new SeedResult();
                row.scenario = scenario;
                row.opportunityId = oppId;
                row.opportunityName = oppsById.get(oppId).Name;
                row.notes = 'Enrichment applied (extra travellers, suppliers, contacts where applicable).';
                response.results.add(row);
            } catch (Exception ex) {
                response.errors.add(scenario + ': ' + ex.getMessage());
            }
        }
        return response;
    }

    private static void enrichScenario(String scenario, Opportunity opp, SharedSuppliers suppliers) {
        Account acc = resolveAccount(opp);
        Id clientGroupId = resolveClientGroupId(opp.Id);

        if (scenario == 'B2C Direct Client') {
            insertExtraTravellers(opp, acc, clientGroupId, new List<ContactSpec>{
                new ContactSpec('Yuki', 'Tanaka', 'yuki.tanaka' + EXTRA_EMAIL_SUFFIX, false, false),
                new ContactSpec('Rei', 'Yamamura', 'rei.yamamura' + EXTRA_EMAIL_SUFFIX, false, false),
                new ContactSpec('Takeshi', 'Uncle', 'takeshi.uncle' + EXTRA_EMAIL_SUFFIX, false, false)
            });
            attachSupplierCostPayments(opp.Id, new List<Id>{ suppliers.hotelId, suppliers.dmcId, suppliers.railId });
            attachOperationalSuppliers(opp, suppliers);
            return;
        }
        if (scenario == 'B2B Agency Routing') {
            insertExtraTravellers(opp, acc, clientGroupId, new List<ContactSpec>{
                new ContactSpec('Sophie', 'Porter', 'sophie.porter' + EXTRA_EMAIL_SUFFIX, false, false),
                new ContactSpec('Liam', 'Porter', 'liam.porter' + EXTRA_EMAIL_SUFFIX, false, false)
            });
            insertExtraAgencyContacts(resolveAgencyId(opp, suppliers), new List<AgencyContactSpec>{
                new AgencyContactSpec('Marcus', 'Webb', 'marcus.webb@wayotravel.verify.test', 'General;Manifest'),
                new AgencyContactSpec('Helen', 'Price', 'helen.price@wayotravel.verify.test', 'Payment')
            });
            attachOperationalSuppliers(opp, suppliers);
            return;
        }
        if (scenario == 'B2B Agent Routing') {
            insertExtraTravellers(opp, acc, clientGroupId, new List<ContactSpec>{
                new ContactSpec('Zoe', 'Grant', 'zoe.grant' + EXTRA_EMAIL_SUFFIX, false, false),
                new ContactSpec('Ethan', 'Grant', 'ethan.grant' + EXTRA_EMAIL_SUFFIX, false, false)
            });
            insertExtraAgencyContacts(resolveAgencyId(opp, suppliers), new List<AgencyContactSpec>{
                new AgencyContactSpec('Billing', 'Coordinator', 'billing@wayotravel.verify.test', 'Payment'),
                new AgencyContactSpec('Manifest', 'Desk', 'manifest@wayotravel.verify.test', 'Manifest')
            });
            attachOperationalSuppliers(opp, suppliers);
            return;
        }
        if (scenario == 'B2B opp with Client docs') {
            insertExtraTravellers(opp, acc, clientGroupId, new List<ContactSpec>{
                new ContactSpec('Priya', 'Singh', 'priya.singh' + EXTRA_EMAIL_SUFFIX, false, false),
                new ContactSpec('Cancelled', 'Guest', 'cancelled.guest' + EXTRA_EMAIL_SUFFIX, false, false, 'Cancelled')
            });
            insertExtraAgencyContacts(resolveAgencyId(opp, suppliers), new List<AgencyContactSpec>{
                new AgencyContactSpec('Agency', 'Coordinator', 'coordinator@wayotravel.verify.test', 'Availability')
            });
            attachOperationalSuppliers(opp, suppliers);
            return;
        }
        if (scenario == 'Supplier-heavy trip') {
            insertExtraTravellers(opp, acc, clientGroupId, new List<ContactSpec>{
                new ContactSpec('Aiko', 'Morita', 'aiko.morita' + EXTRA_EMAIL_SUFFIX, false, false),
                new ContactSpec('Guest', 'Companion', 'guest.companion' + EXTRA_EMAIL_SUFFIX, false, false)
            });
            attachSupplierCostPayments(
                opp.Id,
                new List<Id>{ suppliers.hotelId, suppliers.dmcId, suppliers.railId, suppliers.transportId }
            );
            attachOperationalSuppliers(opp, suppliers);
            linkOpportunitySupplier(opp.Id, suppliers.dmcId);
            linkOpportunitySupplier(opp.Id, suppliers.railId);
            return;
        }
        if (scenario == 'Non-travelling lead booker') {
            insertExtraTravellers(opp, acc, clientGroupId, new List<ContactSpec>{
                new ContactSpec('Sibling', 'Traveller', 'sibling.traveller' + EXTRA_EMAIL_SUFFIX, false, false),
                new ContactSpec('Family', 'Friend', 'family.friend' + EXTRA_EMAIL_SUFFIX, false, false)
            });
            attachSupplierCostPayments(opp.Id, new List<Id>{ suppliers.hotelId, suppliers.dmcId });
            attachOperationalSuppliers(opp, suppliers);
            return;
        }
        if (scenario == 'No traveller emails') {
            insertExtraTravellers(opp, acc, clientGroupId, new List<ContactSpec>{
                new ContactSpec('Companion', 'WithEmail', 'companion.withemail' + EXTRA_EMAIL_SUFFIX, false, false)
            });
            return;
        }
        if (scenario == 'Agency without O_Agent_SC') {
            insertExtraTravellers(opp, acc, clientGroupId, new List<ContactSpec>{
                new ContactSpec('Second', 'Traveller', 'second.traveller' + EXTRA_EMAIL_SUFFIX, false, false),
                new ContactSpec('Third', 'Traveller', 'third.traveller' + EXTRA_EMAIL_SUFFIX, false, false)
            });
            insertExtraAgencyContacts(resolveAgencyId(opp, suppliers), new List<AgencyContactSpec>{
                new AgencyContactSpec('Reservations', 'Team', 'reservations@wayotravel.verify.test', 'Availability'),
                new AgencyContactSpec('Accounts', 'Payable', 'ap@wayotravel.verify.test', 'Payment')
            });
            attachOperationalSuppliers(opp, suppliers);
        }
    }

    private class SharedSuppliers {
        Id agencyId;
        Id agencyContactPrimaryId;
        Id agencyContactOpsId;
        Id hotelId;
        Id dmcId;
        Id railId;
        Id transportId;
    }

    private class AgencyContactSpec {
        String firstName;
        String lastName;
        String email;
        String types;

        AgencyContactSpec(String firstName, String lastName, String email, String types) {
            this.firstName = firstName;
            this.lastName = lastName;
            this.email = email;
            this.types = types;
        }
    }

    private static SharedSuppliers ensureSharedSuppliers() {
        SharedSuppliers existing = loadSharedSuppliersByPrefix();
        if (existing.agencyId != null && existing.hotelId != null) {
            ensureSupplementalSuppliers(existing);
            return existing;
        }
        return createSharedSuppliers();
    }

    private static void ensureSupplementalSuppliers(SharedSuppliers suppliers) {
        if (!Schema.sObjectType.sugati__Supplier__c.isCreateable()) {
            return;
        }
        Id hotelRt = resolveSupplierRecordTypeId('sugati__Hotel');
        Id agencyRt = resolveSupplierRecordTypeId('sugati__Agency');
        Id rt = hotelRt != null ? hotelRt : agencyRt;

        if (suppliers.railId == null) {
            sugati__Supplier__c rail = new sugati__Supplier__c(
                Name = PREFIX + ' JR Rail Pass',
                RecordTypeId = rt,
                sugati__S_Type__c = 'Transport',
                sugati__S_Email__c = 'bookings@jrrail.verify.test'
            );
            insert rail;
            suppliers.railId = rail.Id;
            insertSupplierContactIfMissing(rail.Id, 'Nakamura', 'Ken', 'k.nakamura@jrrail.verify.test', 'General');
        }
        if (suppliers.transportId == null) {
            sugati__Supplier__c transport = new sugati__Supplier__c(
                Name = PREFIX + ' Tokyo Transport Co',
                RecordTypeId = rt,
                sugati__S_Type__c = 'Transport',
                sugati__S_Email__c = 'dispatch@tokyotransport.verify.test'
            );
            insert transport;
            suppliers.transportId = transport.Id;
            insertSupplierContactIfMissing(
                transport.Id,
                'Driver',
                'Pool',
                'drivers@tokyotransport.verify.test',
                'Manifest;Availability'
            );
        }
    }

    private static void insertSupplierContactIfMissing(
        Id supplierId,
        String firstName,
        String lastName,
        String email,
        String types
    ) {
        if (!Schema.sObjectType.sugati__Supplier_Contact__c.isCreateable()) {
            return;
        }
        List<sugati__Supplier_Contact__c> existing = [
            SELECT Id
            FROM sugati__Supplier_Contact__c
            WHERE sugati__SC_Supplier__c = :supplierId
            AND sugati__SC_Email__c = :email
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            insert new sugati__Supplier_Contact__c(
                sugati__SC_Supplier__c = supplierId,
                sugati__SC_First_Name__c = firstName,
                sugati__SC_Last_Name__c = lastName,
                sugati__SC_Email__c = email,
                sugati__Type__c = types
            );
        }
    }

    private static SharedSuppliers loadSharedSuppliersByPrefix() {
        SharedSuppliers out = new SharedSuppliers();
        List<sugati__Supplier__c> suppliers = [
            SELECT Id, Name, sugati__S_Type__c
            FROM sugati__Supplier__c
            WHERE Name LIKE :(PREFIX + '%')
            ORDER BY Name
        ];
        for (sugati__Supplier__c s : suppliers) {
            if (s.Name.contains('Wayo Travel Agency')) {
                out.agencyId = s.Id;
            } else if (s.Name.contains('Park Hyatt')) {
                out.hotelId = s.Id;
            } else if (s.Name.contains('Kyoto DMC')) {
                out.dmcId = s.Id;
            } else if (s.Name.contains('JR Rail')) {
                out.railId = s.Id;
            } else if (s.Name.contains('Tokyo Transport')) {
                out.transportId = s.Id;
            }
        }
        if (out.agencyId != null) {
            for (sugati__Supplier_Contact__c sc : [
                SELECT Id, sugati__SC_Email__c, sugati__SC_First_Name__c
                FROM sugati__Supplier_Contact__c
                WHERE sugati__SC_Supplier__c = :out.agencyId
            ]) {
                if (sc.sugati__SC_Email__c == 'sarah.chen@wayotravel.verify.test') {
                    out.agencyContactPrimaryId = sc.Id;
                } else if (sc.sugati__SC_Email__c == 'ops@wayotravel.verify.test') {
                    out.agencyContactOpsId = sc.Id;
                }
            }
        }
        return out;
    }

    private static SharedSuppliers createSharedSuppliers() {
        SharedSuppliers out = new SharedSuppliers();
        if (!Schema.sObjectType.sugati__Supplier__c.isCreateable()) {
            return out;
        }

        Id agencyRt = resolveSupplierRecordTypeId('sugati__Agency');
        Id hotelRt = resolveSupplierRecordTypeId('sugati__Hotel');

        sugati__Supplier__c agency = new sugati__Supplier__c(
            Name = PREFIX + ' Wayo Travel Agency',
            RecordTypeId = agencyRt,
            sugati__S_Type__c = 'Agency',
            sugati__S_Email__c = 'agency.main@wayotravel.verify.test'
        );
        insert agency;
        out.agencyId = agency.Id;

        sugati__Supplier__c hotel = new sugati__Supplier__c(
            Name = PREFIX + ' Park Hyatt Tokyo',
            RecordTypeId = hotelRt,
            sugati__S_Type__c = 'Hotel',
            sugati__S_Email__c = 'reservations@parkhyatt.verify.test'
        );
        insert hotel;
        out.hotelId = hotel.Id;

        sugati__Supplier__c dmc = new sugati__Supplier__c(
            Name = PREFIX + ' Kyoto DMC Services',
            RecordTypeId = hotelRt != null ? hotelRt : agencyRt,
            sugati__S_Type__c = 'Activity',
            sugati__S_Email__c = 'ops@kyotodmc.verify.test'
        );
        insert dmc;
        out.dmcId = dmc.Id;

        sugati__Supplier__c rail = new sugati__Supplier__c(
            Name = PREFIX + ' JR Rail Pass',
            RecordTypeId = hotelRt != null ? hotelRt : agencyRt,
            sugati__S_Type__c = 'Transport',
            sugati__S_Email__c = 'bookings@jrrail.verify.test'
        );
        insert rail;
        out.railId = rail.Id;

        sugati__Supplier__c transport = new sugati__Supplier__c(
            Name = PREFIX + ' Tokyo Transport Co',
            RecordTypeId = hotelRt != null ? hotelRt : agencyRt,
            sugati__S_Type__c = 'Transport',
            sugati__S_Email__c = 'dispatch@tokyotransport.verify.test'
        );
        insert transport;
        out.transportId = transport.Id;

        if (Schema.sObjectType.sugati__Supplier_Contact__c.isCreateable()) {
            sugati__Supplier_Contact__c agentPrimary = new sugati__Supplier_Contact__c(
                sugati__SC_Supplier__c = agency.Id,
                sugati__SC_First_Name__c = 'Sarah',
                sugati__SC_Last_Name__c = 'Chen',
                sugati__SC_Email__c = 'sarah.chen@wayotravel.verify.test',
                sugati__Type__c = 'General'
            );
            insert agentPrimary;
            out.agencyContactPrimaryId = agentPrimary.Id;

            sugati__Supplier_Contact__c agencyOps = new sugati__Supplier_Contact__c(
                sugati__SC_Supplier__c = agency.Id,
                sugati__SC_First_Name__c = 'Ops',
                sugati__SC_Last_Name__c = 'Desk',
                sugati__SC_Email__c = 'ops@wayotravel.verify.test',
                sugati__Type__c = 'Availability;Payment'
            );
            insert agencyOps;
            out.agencyContactOpsId = agencyOps.Id;

            insert new List<sugati__Supplier_Contact__c>{
                new sugati__Supplier_Contact__c(
                    sugati__SC_Supplier__c = hotel.Id,
                    sugati__SC_First_Name__c = 'Tanaka',
                    sugati__SC_Last_Name__c = 'Yoshiko',
                    sugati__SC_Email__c = 't.yoshiko@parkhyatt.verify.test',
                    sugati__Type__c = 'Availability'
                ),
                new sugati__Supplier_Contact__c(
                    sugati__SC_Supplier__c = hotel.Id,
                    sugati__SC_First_Name__c = 'Ito',
                    sugati__SC_Last_Name__c = 'Shinji',
                    sugati__SC_Email__c = 'i.shinji@parkhyatt.verify.test',
                    sugati__Type__c = 'General;Manifest'
                ),
                new sugati__Supplier_Contact__c(
                    sugati__SC_Supplier__c = dmc.Id,
                    sugati__SC_First_Name__c = 'Suzuki',
                    sugati__SC_Last_Name__c = 'Maiko',
                    sugati__SC_Email__c = 's.maiko@kyotodmc.verify.test',
                    sugati__Type__c = 'Registration;Payment'
                ),
                new sugati__Supplier_Contact__c(
                    sugati__SC_Supplier__c = rail.Id,
                    sugati__SC_First_Name__c = 'Nakamura',
                    sugati__SC_Last_Name__c = 'Ken',
                    sugati__SC_Email__c = 'k.nakamura@jrrail.verify.test',
                    sugati__Type__c = 'General'
                ),
                new sugati__Supplier_Contact__c(
                    sugati__SC_Supplier__c = transport.Id,
                    sugati__SC_First_Name__c = 'Driver',
                    sugati__SC_Last_Name__c = 'Pool',
                    sugati__SC_Email__c = 'drivers@tokyotransport.verify.test',
                    sugati__Type__c = 'Manifest;Availability'
                )
            };
        }

        return out;
    }

    private static SeedResult seedB2cDirectClient(Account acc, String stageName, SharedSuppliers suppliers) {
        Opportunity opp = insertOpportunity(
            PREFIX + ' B2C Direct Client',
            acc.Id,
            stageName,
            null,
            null,
            'Direct To Client'
        );
        TravellerBundle travellers = insertTravellerParty(
            opp,
            acc,
            new List<ContactSpec>{
                new ContactSpec('Hiroshi', 'Yamamura', 'hiroshi.yamamura.verify@test.com', true, false),
                new ContactSpec('Akemi', 'Yamamura', 'akemi.yamamura.verify@test.com', false, false),
                new ContactSpec('Grandma', 'Yamamura', 'grandma.yamamura.verify@test.com', false, false)
            }
        );
        linkLeadClientGroup(opp, travellers.leadGroupMemberId);
        attachOperationalSuppliers(opp, suppliers);
        attachSupplierCostPayments(opp.Id, new List<Id>{ suppliers.hotelId, suppliers.dmcId });

        SeedResult result = baseResult(opp, 'B2C Direct Client');
        result.expectedHubTag = 'B2C';
        result.expectedDefaultTab = 'travellers';
        result.expectedDefaultTo = 'Lead Booker (Hiroshi Yamamura)';
        result.notes = 'Document Communication = Client. Lead booker pre-selected; agency tab empty.';
        return result;
    }

    private static SeedResult seedB2bAgencyRouting(Account acc, String stageName, SharedSuppliers suppliers) {
        Opportunity opp = insertOpportunity(
            PREFIX + ' B2B Agency Routing',
            acc.Id,
            stageName,
            suppliers.agencyId,
            null,
            'Agency'
        );
        TravellerBundle travellers = insertTravellerParty(
            opp,
            acc,
            new List<ContactSpec>{
                new ContactSpec('James', 'Porter', 'james.porter.verify@test.com', true, false),
                new ContactSpec('Emily', 'Porter', 'emily.porter.verify@test.com', false, false)
            }
        );
        linkLeadClientGroup(opp, travellers.leadGroupMemberId);
        attachOperationalSuppliers(opp, suppliers);

        SeedResult result = baseResult(opp, 'B2B Agency Routing');
        result.expectedHubTag = 'B2B';
        result.expectedDefaultTab = 'agents';
        result.expectedDefaultTo = 'Agency main email (agency.main@wayotravel.verify.test)';
        result.notes = 'Travellers visible but not pre-selected. Agency row pre-selected.';
        return result;
    }

    private static SeedResult seedB2bAgentRouting(Account acc, String stageName, SharedSuppliers suppliers) {
        Opportunity opp = insertOpportunity(
            PREFIX + ' B2B Agent Routing',
            acc.Id,
            stageName,
            suppliers.agencyId,
            suppliers.agencyContactPrimaryId,
            'Agent'
        );
        TravellerBundle travellers = insertTravellerParty(
            opp,
            acc,
            new List<ContactSpec>{
                new ContactSpec('Olivia', 'Grant', 'olivia.grant.verify@test.com', true, false),
                new ContactSpec('Noah', 'Grant', 'noah.grant.verify@test.com', false, false)
            }
        );
        linkLeadClientGroup(opp, travellers.leadGroupMemberId);
        attachOperationalSuppliers(opp, suppliers);

        SeedResult result = baseResult(opp, 'B2B Agent Routing');
        result.expectedHubTag = 'B2B';
        result.expectedDefaultTab = 'agents';
        result.expectedDefaultTo = 'Agent Contact (Sarah Chen)';
        result.notes = 'O_Agent_SC set. Agent Contact row pre-selected, not agency main inbox.';
        return result;
    }

    private static SeedResult seedB2bOppClientDocs(Account acc, String stageName, SharedSuppliers suppliers) {
        Opportunity opp = insertOpportunity(
            PREFIX + ' B2B Opp Client Docs',
            acc.Id,
            stageName,
            suppliers.agencyId,
            suppliers.agencyContactPrimaryId,
            'Direct To Client'
        );
        TravellerBundle travellers = insertTravellerParty(
            opp,
            acc,
            new List<ContactSpec>{
                new ContactSpec('Maya', 'Singh', 'maya.singh.verify@test.com', true, false),
                new ContactSpec('Arjun', 'Singh', 'arjun.singh.verify@test.com', false, false)
            }
        );
        linkLeadClientGroup(opp, travellers.leadGroupMemberId);
        attachOperationalSuppliers(opp, suppliers);

        SeedResult result = baseResult(opp, 'B2B opp with Client docs');
        result.expectedHubTag = 'B2B';
        result.expectedDefaultTab = 'travellers';
        result.expectedDefaultTo = 'Lead Booker (Maya Singh) despite agency on opp';
        result.notes = 'Has agency but Document Communication = Client. Hub tag B2B, default TO still lead booker.';
        return result;
    }

    private static SeedResult seedSupplierHeavyTrip(Account acc, String stageName, SharedSuppliers suppliers) {
        Opportunity opp = insertOpportunity(
            PREFIX + ' Supplier-Heavy Trip',
            acc.Id,
            stageName,
            null,
            null,
            'Direct To Client'
        );
        TravellerBundle travellers = insertTravellerParty(
            opp,
            acc,
            new List<ContactSpec>{
                new ContactSpec('Kenji', 'Morita', 'kenji.morita.verify@test.com', true, false)
            }
        );
        linkLeadClientGroup(opp, travellers.leadGroupMemberId);
        attachOperationalSuppliers(opp, suppliers);

        linkOpportunitySupplier(opp.Id, suppliers.dmcId);
        linkOpportunitySupplier(opp.Id, suppliers.railId);
        attachSupplierCostPayments(
            opp.Id,
            new List<Id>{ suppliers.hotelId, suppliers.dmcId, suppliers.railId, suppliers.transportId }
        );

        SeedResult result = baseResult(opp, 'Supplier-heavy trip');
        result.expectedHubTag = 'B2C';
        result.expectedDefaultTab = 'travellers';
        result.expectedDefaultTo = 'Lead Booker (Kenji Morita)';
        result.notes = 'Multiple suppliers + typed contacts (Availability, Payment, Manifest, Registration). Use supplier templates to verify To_Address_Filter.';
        return result;
    }

    private static SeedResult seedNonTravellingLeadBooker(Account acc, String stageName, SharedSuppliers suppliers) {
        Opportunity opp = insertOpportunity(
            PREFIX + ' Non-Travelling Lead Booker',
            acc.Id,
            stageName,
            null,
            null,
            'Direct To Client'
        );
        TravellerBundle travellers = insertTravellerParty(
            opp,
            acc,
            new List<ContactSpec>{
                new ContactSpec('Parent', 'Booker', 'parent.booker.verify@test.com', true, true),
                new ContactSpec('Child', 'Traveller', 'child.traveller.verify@test.com', false, false)
            }
        );
        linkLeadClientGroup(opp, travellers.leadGroupMemberId);
        attachOperationalSuppliers(opp, suppliers);

        SeedResult result = baseResult(opp, 'Non-travelling lead booker');
        result.expectedHubTag = 'B2C';
        result.expectedDefaultTab = 'travellers';
        result.expectedDefaultTo = 'Lead Booker (Parent Booker)';
        result.notes = 'Lead booker flagged Non Travelling Lead Booker; still pre-selected for client routing.';
        return result;
    }

    private static SeedResult seedMinimalNoTravellerEmails(Account acc, String stageName) {
        Opportunity opp = insertOpportunity(
            PREFIX + ' No Traveller Emails',
            acc.Id,
            stageName,
            null,
            null,
            'Direct To Client'
        );
        if (Schema.sObjectType.sugati__Group_Member__c.isCreateable()) {
            Contact c = insertContact(acc, 'No', 'EmailTraveller', null);
            insertGroupMember(opp, c.Id, null, 'On Request', false, false);
        }

        SeedResult result = baseResult(opp, 'No traveller emails');
        result.expectedHubTag = 'B2C';
        result.expectedDefaultTab = 'travellers';
        result.expectedDefaultTo = 'None (traveller omitted from picker when email blank)';
        result.notes = 'Traveller without email should not appear in recipient list.';
        return result;
    }

    private static SeedResult seedAgencyNoAgentContact(Account acc, String stageName, SharedSuppliers suppliers) {
        Opportunity opp = insertOpportunity(
            PREFIX + ' Agency No Named Agent',
            acc.Id,
            stageName,
            suppliers.agencyId,
            null,
            'Agent'
        );
        TravellerBundle travellers = insertTravellerParty(
            opp,
            acc,
            new List<ContactSpec>{
                new ContactSpec('Agent', 'Fallback', 'agent.fallback.verify@test.com', true, false)
            }
        );
        linkLeadClientGroup(opp, travellers.leadGroupMemberId);

        SeedResult result = baseResult(opp, 'Agency without O_Agent_SC');
        result.expectedHubTag = 'B2B';
        result.expectedDefaultTab = 'agents';
        result.expectedDefaultTo = 'No agent contact row; template TO may be empty until agent picked';
        result.notes = 'Document Communication = Agent but O_Agent_SC blank. Agency tab shows agency only.';
        return result;
    }

    private static Opportunity insertOpportunity(
        String name,
        Id accountId,
        String stageName,
        Id agencyId,
        Id agentContactId,
        String documentCommunication
    ) {
        Opportunity opp = new Opportunity(
            Name = name,
            StageName = stageName,
            CloseDate = Date.today().addDays(45),
            AccountId = accountId,
            Amount = 12000
        );
        if (agencyId != null) {
            opp.put('sugati__O_Agent__c', agencyId);
        }
        if (agentContactId != null) {
            opp.put('sugati__O_Agent_SC__c', agentContactId);
        }
        if (String.isNotBlank(documentCommunication)) {
            opp.put('sugati__O_Document_Communication__c', documentCommunication);
        }
        insert opp;
        return opp;
    }

    private class ContactSpec {
        String firstName;
        String lastName;
        String email;
        Boolean lead;
        Boolean nonTravellingLeadBooker;
        String bookingStatus;

        ContactSpec(String firstName, String lastName, String email, Boolean lead, Boolean nonTravellingLeadBooker) {
            this(firstName, lastName, email, lead, nonTravellingLeadBooker, 'Booked');
        }

        ContactSpec(
            String firstName,
            String lastName,
            String email,
            Boolean lead,
            Boolean nonTravellingLeadBooker,
            String bookingStatus
        ) {
            this.firstName = firstName;
            this.lastName = lastName;
            this.email = email;
            this.lead = lead;
            this.nonTravellingLeadBooker = nonTravellingLeadBooker;
            this.bookingStatus = bookingStatus;
        }
    }

    private class TravellerBundle {
        Id leadGroupMemberId;
    }

    private static TravellerBundle insertTravellerParty(Opportunity opp, Account acc, List<ContactSpec> specs) {
        return insertTravellerParty(opp, acc, specs, null);
    }

    private static TravellerBundle insertTravellerParty(
        Opportunity opp,
        Account acc,
        List<ContactSpec> specs,
        Id existingClientGroupId
    ) {
        TravellerBundle bundle = new TravellerBundle();
        if (!Schema.sObjectType.sugati__Group_Member__c.isCreateable()) {
            return bundle;
        }

        Id clientGroupId = existingClientGroupId;
        if (clientGroupId == null && Schema.sObjectType.sugati__Client_Group__c.isCreateable()) {
            sugati__Client_Group__c cg = new sugati__Client_Group__c(sugati__CG_Opportunity__c = opp.Id);
            insert cg;
            clientGroupId = cg.Id;
        }

        for (ContactSpec spec : specs) {
            Contact c = insertContact(acc, spec.firstName, spec.lastName, spec.email);
            String status = String.isNotBlank(spec.bookingStatus) ? spec.bookingStatus : 'Booked';
            Id gmId = insertGroupMember(
                opp,
                c.Id,
                clientGroupId,
                status,
                spec.lead,
                spec.nonTravellingLeadBooker
            );
            if (spec.lead) {
                bundle.leadGroupMemberId = gmId;
            }
        }
        return bundle;
    }

    private static Contact insertContact(Account acc, String firstName, String lastName, String email) {
        Contact c = new Contact(
            FirstName = firstName,
            LastName = lastName,
            Email = email,
            AccountId = acc.Id
        );
        insert c;
        return c;
    }

    private static Id insertGroupMember(
        Opportunity opp,
        Id contactId,
        Id clientGroupId,
        String bookingStatus,
        Boolean leadPassenger,
        Boolean nonTravellingLeadBooker
    ) {
        sugati__Group_Member__c gm = new sugati__Group_Member__c(
            sugati__GM_Opportunity__c = opp.Id,
            sugati__GM_Contact__c = contactId
        );
        if (clientGroupId != null) {
            gm.sugati__GM_Client_Group__c = clientGroupId;
        }
        gm.put('sugati__S_GM_Client_Group_Booking_Status__c', bookingStatus);
        if (leadPassenger) {
            gm.put('sugati__GM_Lead_Passenger__c', true);
        }
        if (nonTravellingLeadBooker) {
            gm.put('sugati__GM_Non_Travelling_Lead_Booker__c', true);
        }
        insert gm;
        return gm.Id;
    }

    private static void linkLeadClientGroup(Opportunity opp, Id leadGroupMemberId) {
        if (leadGroupMemberId == null || !Schema.sObjectType.sugati__Client_Group__c.isUpdateable()) {
            return;
        }
        List<sugati__Client_Group__c> groups = [
            SELECT Id
            FROM sugati__Client_Group__c
            WHERE sugati__CG_Opportunity__c = :opp.Id
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        if (groups.isEmpty()) {
            return;
        }
        groups[0].sugati__CG_Lead_Group_Member__c = leadGroupMemberId;
        update groups[0];
        opp.put('sugati__O_Lead_CG__c', groups[0].Id);
        update opp;
    }

    private static void attachOperationalSuppliers(Opportunity opp, SharedSuppliers suppliers) {
        if (suppliers == null || !Schema.sObjectType.sugati__Supplier_Booking__c.isCreateable()) {
            return;
        }
        Set<Id> existingSupplierIds = new Set<Id>();
        for (sugati__Supplier_Booking__c sb : [
            SELECT sugati__SB_Supplier__c
            FROM sugati__Supplier_Booking__c
            WHERE sugati__SB_Opportunity__c = :opp.Id
            AND sugati__SB_Supplier__c != null
        ]) {
            existingSupplierIds.add(sb.sugati__SB_Supplier__c);
        }

        List<sugati__Supplier_Booking__c> bookings = new List<sugati__Supplier_Booking__c>();
        Integer dayOffset = 30;
        for (Id supplierId : new List<Id>{
            suppliers.hotelId,
            suppliers.dmcId,
            suppliers.railId,
            suppliers.transportId
        }) {
            if (supplierId == null || existingSupplierIds.contains(supplierId)) {
                continue;
            }
            bookings.add(
                new sugati__Supplier_Booking__c(
                    sugati__SB_Opportunity__c = opp.Id,
                    sugati__SB_Supplier__c = supplierId,
                    sugati__SB_From_Date__c = Date.today().addDays(dayOffset)
                )
            );
            dayOffset += 2;
        }
        if (!bookings.isEmpty()) {
            insert bookings;
        }
    }

    private static void attachSupplierCostPayments(Id opportunityId, List<Id> supplierIds) {
        if (
            opportunityId == null ||
            !Schema.sObjectType.sugati__Supplier_Cost_Payment__c.isCreateable() ||
            supplierIds == null
        ) {
            return;
        }
        Set<Id> existing = new Set<Id>();
        for (sugati__Supplier_Cost_Payment__c row : [
            SELECT sugati__SCP_Supplier__c
            FROM sugati__Supplier_Cost_Payment__c
            WHERE sugati__SCP_Opportunity__c = :opportunityId
            AND sugati__SCP_Supplier__c != null
        ]) {
            existing.add(row.sugati__SCP_Supplier__c);
        }
        List<sugati__Supplier_Cost_Payment__c> rows = new List<sugati__Supplier_Cost_Payment__c>();
        for (Id supplierId : supplierIds) {
            if (supplierId != null && !existing.contains(supplierId)) {
                rows.add(
                    new sugati__Supplier_Cost_Payment__c(
                        sugati__SCP_Opportunity__c = opportunityId,
                        sugati__SCP_Supplier__c = supplierId
                    )
                );
            }
        }
        if (!rows.isEmpty()) {
            insert rows;
        }
    }

    private static void linkOpportunitySupplier(Id opportunityId, Id supplierId) {
        if (
            opportunityId == null ||
            supplierId == null ||
            !Schema.sObjectType.sugati__Opportunity_Supplier__c.isCreateable()
        ) {
            return;
        }
        List<sugati__Opportunity_Supplier__c> existing = [
            SELECT Id
            FROM sugati__Opportunity_Supplier__c
            WHERE sugati__OS_Opportunity__c = :opportunityId
            AND sugati__OS_Supplier__c = :supplierId
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            insert new sugati__Opportunity_Supplier__c(
                sugati__OS_Opportunity__c = opportunityId,
                sugati__OS_Supplier__c = supplierId
            );
        }
    }

    private static void insertExtraTravellers(
        Opportunity opp,
        Account acc,
        Id clientGroupId,
        List<ContactSpec> specs
    ) {
        if (specs == null || specs.isEmpty() || !Schema.sObjectType.sugati__Group_Member__c.isCreateable()) {
            return;
        }
        Set<String> targetEmails = new Set<String>();
        for (ContactSpec spec : specs) {
            if (String.isNotBlank(spec.email)) {
                targetEmails.add(spec.email.toLowerCase());
            }
        }
        if (targetEmails.isEmpty()) {
            return;
        }
        Set<String> existingEmails = new Set<String>();
        for (sugati__Group_Member__c gm : [
            SELECT sugati__GM_Contact__r.Email
            FROM sugati__Group_Member__c
            WHERE sugati__GM_Opportunity__c = :opp.Id
            AND sugati__GM_Contact__r.Email != null
        ]) {
            existingEmails.add(gm.sugati__GM_Contact__r.Email.toLowerCase());
        }
        List<ContactSpec> pending = new List<ContactSpec>();
        for (ContactSpec spec : specs) {
            if (String.isBlank(spec.email) || existingEmails.contains(spec.email.toLowerCase())) {
                continue;
            }
            pending.add(spec);
        }
        if (pending.isEmpty()) {
            return;
        }
        if (clientGroupId == null) {
            clientGroupId = resolveClientGroupId(opp.Id);
        }
        insertTravellerParty(opp, acc, pending, clientGroupId);
    }

    private static void insertExtraAgencyContacts(Id agencyId, List<AgencyContactSpec> specs) {
        if (
            agencyId == null ||
            specs == null ||
            specs.isEmpty() ||
            !Schema.sObjectType.sugati__Supplier_Contact__c.isCreateable()
        ) {
            return;
        }
        Set<String> targetEmails = new Set<String>();
        for (AgencyContactSpec spec : specs) {
            targetEmails.add(spec.email.toLowerCase());
        }
        Set<String> existingEmails = new Set<String>();
        for (sugati__Supplier_Contact__c sc : [
            SELECT sugati__SC_Email__c
            FROM sugati__Supplier_Contact__c
            WHERE sugati__SC_Supplier__c = :agencyId
            AND sugati__SC_Email__c != null
        ]) {
            existingEmails.add(sc.sugati__SC_Email__c.toLowerCase());
        }
        List<sugati__Supplier_Contact__c> rows = new List<sugati__Supplier_Contact__c>();
        for (AgencyContactSpec spec : specs) {
            if (existingEmails.contains(spec.email.toLowerCase())) {
                continue;
            }
            rows.add(
                new sugati__Supplier_Contact__c(
                    sugati__SC_Supplier__c = agencyId,
                    sugati__SC_First_Name__c = spec.firstName,
                    sugati__SC_Last_Name__c = spec.lastName,
                    sugati__SC_Email__c = spec.email,
                    sugati__Type__c = spec.types
                )
            );
        }
        if (!rows.isEmpty()) {
            insert rows;
        }
    }

    private static Account resolveAccount(Opportunity opp) {
        if (opp.AccountId == null) {
            Account acc = new Account(Name = PREFIX + ' Enrich Account');
            insert acc;
            opp.AccountId = acc.Id;
            update opp;
            return acc;
        }
        return [SELECT Id FROM Account WHERE Id = :opp.AccountId LIMIT 1];
    }

    private static Id resolveAgencyId(Opportunity opp, SharedSuppliers suppliers) {
        return opp.sugati__O_Agent__c != null ? opp.sugati__O_Agent__c : suppliers.agencyId;
    }

    private static Id resolveClientGroupId(Id opportunityId) {
        List<sugati__Client_Group__c> groups = [
            SELECT Id
            FROM sugati__Client_Group__c
            WHERE sugati__CG_Opportunity__c = :opportunityId
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];
        return groups.isEmpty() ? null : groups[0].Id;
    }

    private static SeedResult baseResult(Opportunity opp, String scenario) {
        SeedResult result = new SeedResult();
        result.scenario = scenario;
        result.opportunityId = opp.Id;
        result.opportunityName = opp.Name;
        return result;
    }

    private static String resolveStageName() {
        List<OpportunityStage> openStages = [
            SELECT MasterLabel
            FROM OpportunityStage
            WHERE IsActive = TRUE AND IsClosed = FALSE
            LIMIT 1
        ];
        if (!openStages.isEmpty()) {
            return openStages[0].MasterLabel;
        }
        return [SELECT MasterLabel FROM OpportunityStage WHERE IsActive = TRUE LIMIT 1].MasterLabel;
    }

    private static Id resolveSupplierRecordTypeId(String developerName) {
        Map<String, Schema.RecordTypeInfo> byDevName =
            Schema.SObjectType.sugati__Supplier__c.getRecordTypeInfosByDeveloperName();
        if (byDevName.containsKey(developerName) && byDevName.get(developerName).isAvailable()) {
            return byDevName.get(developerName).getRecordTypeId();
        }
        for (Schema.RecordTypeInfo info : byDevName.values()) {
            if (info.isAvailable() && !info.isMaster()) {
                return info.getRecordTypeId();
            }
        }
        return null;
    }
}
