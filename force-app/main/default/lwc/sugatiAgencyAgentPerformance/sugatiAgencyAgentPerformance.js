import { LightningElement, api } from 'lwc';

/**
 * Avatar gradient styles for agent rows, cycled by index.
 * First three match gold/silver/bronze rank colours.
 */
const AVATAR_GRADIENTS = [
    'background:linear-gradient(135deg,#ffd700,#b8860b);color:#1C1C1A',
    'background:linear-gradient(135deg,#c0c0c0,#888);color:#1C1C1A',
    'background:linear-gradient(135deg,#cd7f32,#8b4513);color:#fff',
    'background:linear-gradient(135deg,#7ab8e0,#4a8fb0);color:#fff',
    'background:linear-gradient(135deg,#4caf82,#2a7a54);color:#fff',
    'background:linear-gradient(135deg,#8bc48a,#4a774a);color:#fff',
    'background:linear-gradient(135deg,#c4a08a,#8a6050);color:#fff',
    'background:linear-gradient(135deg,#9b59b6,#8e44ad);color:#fff'
];

/** Maximum number of agents shown before the View All button appears */
const AGENT_DISPLAY_LIMIT = 6;

/**
 * Agent Performance component for the Agency page.
 * Displays a sortable table of agent performance metrics derived from
 * Supplier Bookings, grouped by contact and filtered by year.
 * Supports year switching, view-all toggle and CSV export.
 */
export default class SugatiAgencyAgentPerformance extends LightningElement {

    // ---- PRIVATE MEMBER VARIABLES ----

    _supplierBookings = [];
    _supplierContacts = [];
    _currencySymbol   = '£';

    // ---- PUBLIC MEMBER VARIABLES ----

    /** Currently selected year for filtering — defaults to current year */
    activeYear    = new Date().getFullYear();

    /** Whether all agents are shown or only the top AGENT_DISPLAY_LIMIT */
    showAllAgents = false;

    /** Processed agent display objects derived from bookings and contacts */
    dynamicAgents = [];

    // ---- API SETTERS / GETTERS ----

    /**
     * Supplier Booking records passed from the parent component.
     * Triggers agent processing when updated.
     */
    @api
    get supplierBookings() {
        return this._supplierBookings;
    }
    set supplierBookings(supplierBookingsValue) {
        this._supplierBookings = supplierBookingsValue || [];
        this.processAgents();
    }

    /**
     * Supplier Contact records passed from the parent component.
     * Each contact represents one agent row in the table.
     * Triggers agent processing when updated.
     */
    @api
    get supplierContacts() {
        return this._supplierContacts;
    }
    set supplierContacts(supplierContactsValue) {
        this._supplierContacts = supplierContactsValue || [];
        this.processAgents();
    }

    /**
     * Currency symbol passed from the parent component.
     * Triggers agent processing when updated.
     */
    @api
    get currencySymbol() {
        return this._currencySymbol;
    }
    set currencySymbol(currencySymbolValue) {
        this._currencySymbol = currencySymbolValue || '£';
        this.processAgents();
    }

    // ---- PUBLIC METHODS ----

    /**
     * Builds the dynamicAgents array from supplier contacts and bookings.
     * Each contact gets one row. Revenue and nights are summed from
     * unique Opportunities linked via the O_Agent_SC__c field.
     * Only bookings matching the currently selected year are included.
     */
    processAgents() {
        const currencySymbolValue = this._currencySymbol;

        // Step 1 — seed one entry per contact so agents with no bookings appear
        const agentDataById = {};
        (this._supplierContacts || []).forEach(supplierContact => {
            const firstName = supplierContact.sugati__SC_First_Name__c || '';
            const lastName  = supplierContact.sugati__SC_Last_Name__c  || '';
            const fullName  = (firstName + ' ' + lastName).trim()
                || supplierContact.sugati__SC_Name__c
                || 'Unknown';

            agentDataById[supplierContact.Id] = {
                id:       supplierContact.Id,
                name:     fullName,
                role:     supplierContact.sugati__SC_Title__c || '',
                initials: fullName.split(' ').filter(Boolean).slice(0, 2)
                              .map(word => word.charAt(0).toUpperCase()).join(''),
                oppIds:   new Set(),
                revenue:  0,
                nights:   0
            };
        });

        // Step 2 — loop bookings, match to agent via O_Agent_SC__c lookup on Opportunity
        // Use processedOppIds to avoid double-counting the same Opportunity
        const processedOppIds = {};

        (this._supplierBookings || []).forEach(supplierBooking => {
            const opportunity = supplierBooking.sugati__SB_Opportunity__r;
            if (!opportunity) {
                return;
            }

            const bookingDate = opportunity.sugati__O_Booking_Date__c;
            if (!bookingDate) {
                return;
            }

            if (new Date(bookingDate).getFullYear() !== this.activeYear) {
                return;
            }

            const agentContactId = opportunity.sugati__O_Agent_SC__c;
            if (!agentContactId || !agentDataById[agentContactId]) {
                return;
            }

            const opportunityId = supplierBooking.sugati__SB_Opportunity__c;
            const agentData     = agentDataById[agentContactId];

            agentData.oppIds.add(opportunityId);

            // Sum Amount and nights once per unique Opportunity
            if (!processedOppIds[opportunityId]) {
                processedOppIds[opportunityId] = true;
                agentData.revenue += parseFloat(opportunity.Amount) || 0;
                agentData.nights  += parseFloat(opportunity.sugati__O_No_of_Nights__c) || 0;
            }
        });

        // Step 3 — sort by revenue descending (zero-revenue agents go to bottom)
        const sortedAgents = Object.values(agentDataById)
            .sort((firstAgent, secondAgent) => secondAgent.revenue - firstAgent.revenue);

        // Step 4 — map to display objects with formatted values and status badges
        this.dynamicAgents = sortedAgents.map((agentData, index) => {
            const rank               = index + 1;
            const uniqueBookingCount = agentData.oppIds.size;
            const avgBookingValue    = uniqueBookingCount > 0
                ? agentData.revenue / uniqueBookingCount
                : 0;
            const agentStatus  = this.getAgentStatus(rank, agentData.revenue);
            const rankClass    = rank <= 3 ? `rank-badge rank-${rank}` : 'rank-badge rank-other';
            const rankStyle    = rank > 3  ? 'color:var(--text-muted)' : '';

            return {
                id:          agentData.id,
                rank,
                rankClass,
                rankStyle,
                name:        agentData.name,
                role:        agentData.role,
                initials:    agentData.initials,
                avatarStyle: AVATAR_GRADIENTS[index % AVATAR_GRADIENTS.length],
                bookings:    uniqueBookingCount,
                nights:      Math.round(agentData.nights),
                revenue:     this.formatValue(agentData.revenue, currencySymbolValue),
                avg:         uniqueBookingCount > 0
                    ? this.formatValue(avgBookingValue, currencySymbolValue)
                    : '—',
                status:      agentStatus.label,
                statusBadge: agentStatus.cssClass,
                sparkbars:   []
            };
        });
    }

    // ---- PUBLIC GETTERS ----

    /**
     * Returns the agents to display — either all or capped at AGENT_DISPLAY_LIMIT.
     * @returns {Array} Array of agent display objects
     */
    get displayedAgents() {
        return this.showAllAgents
            ? this.dynamicAgents
            : this.dynamicAgents.slice(0, AGENT_DISPLAY_LIMIT);
    }

    /**
     * Returns the CSS class for the table wrap, toggling overflow-y
     * when all agents are visible.
     * @returns {string} CSS class string
     */
    get tableWrapClass() {
        return this.showAllAgents ? 'table-wrap expanded' : 'table-wrap';
    }

    /**
     * Returns the total number of processed agents.
     * @returns {number}
     */
    get totalAgentCount() {
        return this.dynamicAgents.length;
    }

    /**
     * Returns true if there are more agents than the display limit.
     * @returns {boolean}
     */
    get hasMore() {
        return this.dynamicAgents.length > AGENT_DISPLAY_LIMIT;
    }

    /**
     * Returns true if at least one agent exists.
     * @returns {boolean}
     */
    get hasAgents() {
        return this.dynamicAgents.length > 0;
    }

    /**
     * Returns the previous calendar year.
     * @returns {number}
     */
    get previousYear() {
        return new Date().getFullYear() - 1;
    }

    /**
     * Returns the current calendar year.
     * @returns {number}
     */
    get currentYear() {
        return new Date().getFullYear();
    }

    /**
     * Returns the CSS class for the previous year tab.
     * @returns {string}
     */
    get previousYearTabClass() {
        return `year-tab ${this.activeYear === this.previousYear ? 'active' : ''}`;
    }

    /**
     * Returns the CSS class for the current year tab.
     * @returns {string}
     */
    get currentYearTabClass() {
        return `year-tab ${this.activeYear === this.currentYear ? 'active' : ''}`;
    }

    /**
     * Returns the label for the view-all toggle button.
     * @returns {string}
     */
    get viewAllButtonText() {
        return this.showAllAgents
            ? 'Show top 6 agents ↑'
            : `View all ${this.dynamicAgents.length} agents →`;
    }

    // ---- EVENT HANDLERS ----

    /**
     * Handles year tab click. Updates activeYear and re-processes agents.
     * @param {Event} event - Click event from the year tab element
     */
    setYear(event) {
        this.activeYear = parseInt(event.target.dataset.year, 10);
        this.processAgents();
    }

    /**
     * Toggles between showing all agents and the top AGENT_DISPLAY_LIMIT agents.
     */
    handleViewAllAgents() {
        this.showAllAgents = !this.showAllAgents;
    }

    /**
     * Generates and downloads a CSV file of all agent performance data.
     * Filename includes the currently selected year.
     */
    handleExportReport() {
        const headers = [
            'Rank', 'Name', 'Role', 'Bookings',
            'Revenue (YTD)', 'Bed Nights', 'Avg Booking', 'Status'
        ];
        const rows = this.dynamicAgents.map(agentRow => [
            agentRow.rank, agentRow.name, agentRow.role, agentRow.bookings,
            agentRow.revenue, agentRow.nights, agentRow.avg, agentRow.status
        ]);
        const csvContent = [headers, ...rows]
            .map(row => row
                .map(cellValue => `"${String(cellValue ?? '').replace(/"/g, '""')}"`)
                .join(','))
            .join('\n');

        const downloadLink = document.createElement('a');
        downloadLink.setAttribute(
            'href',
            'data:text/csv;charset=utf-8,' + encodeURIComponent(csvContent)
        );
        downloadLink.setAttribute('download', `agent_performance_${this.activeYear}.csv`);
        document.body.appendChild(downloadLink);
        downloadLink.click();
        document.body.removeChild(downloadLink);
    }

    // ---- PRIVATE METHODS ----

    /**
     * Returns a status label and CSS badge class based on the agent's
     * rank position and revenue for the selected year.
     * @param {number} rank    - The agent's rank (1 = highest revenue)
     * @param {number} revenue - The agent's total revenue for the year
     * @returns {object} Object containing label and cssClass strings
     */
    getAgentStatus(rank, revenue) {
        if (revenue === 0) {
            return { label: 'No Activity',   cssClass: 'badge badge-grey' };
        }
        if (rank === 1) {
            return { label: 'Top Performer', cssClass: 'badge badge-sunset' };
        }
        if (rank === 2) {
            return { label: 'Rising',        cssClass: 'badge badge-green' };
        }
        if (rank === 3) {
            return { label: 'Strong',        cssClass: 'badge badge-green' };
        }
        if (rank === 4) {
            return { label: 'Stable',        cssClass: 'badge badge-blue' };
        }
        if (rank === 5) {
            return { label: 'Improving',     cssClass: 'badge badge-blue' };
        }
        return { label: 'Needs Review', cssClass: 'badge badge-red' };
    }

    /**
     * Formats a numeric value into a human-readable string
     * with the appropriate currency symbol and K/M suffix.
     * @param {number} numericValue        - The raw numeric value to format
     * @param {string} currencySymbolToUse - The currency symbol to prepend
     * @returns {string} Formatted string e.g. '£284K', '£1.2M', '£750'
     */
    formatValue(numericValue, currencySymbolToUse) {
        const parsed = parseFloat(numericValue);
        if (!parsed || isNaN(parsed)) {
            return `${currencySymbolToUse}0`;
        }
        if (parsed >= 1_000_000) {
            return `${currencySymbolToUse}${(parsed / 1_000_000).toFixed(1).replace(/\.0$/, '')}M`;
        }
        if (parsed >= 1_000) {
            return `${currencySymbolToUse}${(parsed / 1_000).toFixed(1).replace(/\.0$/, '')}K`;
        }
        return `${currencySymbolToUse}${Math.round(parsed).toLocaleString('en-GB')}`;
    }

}