import { LightningElement, api, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getRecipients from '@salesforce/apex/SugatiCommunicationHubController.getRecipients';

export default class SugatiCommunicationRecipientSelector extends LightningElement {
    _selectedIds = [];
    _selectedEmails = [];
    @api opportunityId;

    activeTab = 'travellers';
    statusFilter = 'all';
    _travellers = [];
    _suppliers = [];
    _contacts = [];
    _agents = [];

    @api
    get selectedIds() {
        return this._selectedIds;
    }

    set selectedIds(value) {
        this._selectedIds = Array.isArray(value) ? value : [];
        this.applyPreselection();
    }

    @api
    get selectedEmails() {
        return this._selectedEmails;
    }

    set selectedEmails(value) {
        this._selectedEmails = Array.isArray(value) ? value : [];
        this.applyPreselection();
    }

    @wire(getRecipients, { opportunityId: '$opportunityId' })
    wiredRecipients({ data }) {
        if (!data || !data.length) {
            return;
        }
        const mapped = data.map((r) => ({
            ...r,
            id: r.id,
            rowKey: r.id,
            contactId: r.contactId || null,
            audience: r.audience || 'travellers',
            initials: r.initials || this.computeInitials(r.name),
            name: r.name,
            email: r.email,
            role: r.role || 'Traveller',
            roleKey: r.roleKey || 'traveller',
            status: r.status || 'Booked',
            statusKey: r.statusKey || 'booked',
            linkedToLabel: r.linkedToLabel || '',
            avClass: r.roleKey === 'lead' ? 'av-gold' : 'av-blue',
            selected: Boolean(r.selected)
        }));
        this._travellers = mapped.filter((r) => (r.audience || 'travellers') === 'travellers');
        this._suppliers = mapped.filter((r) => r.audience === 'suppliers');
        this._contacts = mapped.filter((r) => r.audience === 'contacts');
        this._agents = mapped.filter((r) => r.audience === 'agents');
        this.applyPreselection();
    }

    get tabs() {
        return [
            { id: 'travellers', label: '🧳 Travellers', count: this._travellers.length, className: this.activeTab === 'travellers' ? 'rec-aud-tab on' : 'rec-aud-tab' },
            { id: 'agents',     label: '🏢 Agency',      count: this._agents.length || null, className: this.activeTab === 'agents' ? 'rec-aud-tab on' : 'rec-aud-tab' },
            { id: 'suppliers',  label: '🏨 Suppliers',   count: this._suppliers.length, className: this.activeTab === 'suppliers' ? 'rec-aud-tab on' : 'rec-aud-tab' },
            { id: 'contacts',   label: '📋 Sup. Contacts', count: this._contacts.length, className: this.activeTab === 'contacts' ? 'rec-aud-tab on' : 'rec-aud-tab' }
        ];
    }

    get statusTabs() {
        const counts = this.statusCounts;
        return [
            { id: 'all',       label: 'All',          count: counts.all,       countClass: 'rec-stab-n',           className: this.statusFilter === 'all'       ? 'rec-stab on' : 'rec-stab' },
            { id: 'booked',    label: 'Booked',       count: counts.booked,    countClass: 'rec-stab-n booked',    className: this.statusFilter === 'booked'    ? 'rec-stab on' : 'rec-stab' },
            { id: 'request',   label: 'On Request',   count: counts.request,   countClass: 'rec-stab-n request',   className: this.statusFilter === 'request'   ? 'rec-stab on' : 'rec-stab' },
            { id: 'waiting',   label: 'Waiting List', count: counts.waiting,   countClass: 'rec-stab-n waiting',   className: this.statusFilter === 'waiting'   ? 'rec-stab on' : 'rec-stab' },
            { id: 'cancelled', label: 'Cancelled',    count: counts.cancelled, countClass: 'rec-stab-n cancelled', className: this.statusFilter === 'cancelled' ? 'rec-stab on' : 'rec-stab' }
        ];
    }

    get showTravellers() { return this.activeTab === 'travellers'; }
    get showSuppliers()  { return this.activeTab === 'suppliers'; }
    get showAgentsEmpty(){ return this.activeTab === 'agents' && this._agents.length === 0; }
    get showContacts()   { return this.activeTab === 'contacts' && this._contacts.length === 0; }
    get showAgentsList() { return this.activeTab === 'agents' && this._agents.length > 0; }
    get showContactsList() { return this.activeTab === 'contacts' && this._contacts.length > 0; }

    get visibleRecipients() {
        const list =
            this.activeTab === 'suppliers'
                ? this._suppliers
                : this.activeTab === 'contacts'
                  ? this._contacts
                  : this.activeTab === 'agents'
                    ? this._agents
                    : this._travellers;
        return list
            .filter((r) => {
                if (this.activeTab !== 'travellers') return true;
                if (this.statusFilter === 'all') return true;
                return r.statusKey === this.statusFilter;
            })
            .map((r) => ({
                ...r,
                rowKey: r.rowKey || r.id,
                rowClass: r.selected ? 'rec-item sel' : 'rec-item',
                cbClass: r.selected ? 'rec-cb on' : 'rec-cb',
                roleClass: `rec-role-badge ${r.roleKey}`,
                statusClass: `rec-status-badge ${r.statusKey}`,
                showLinkedTo: this.activeTab === 'contacts' && Boolean(r.linkedToLabel)
            }));
    }

    get selectedCount() {
        return [...this._travellers, ...this._suppliers, ...this._contacts, ...this._agents].filter((r) => r.selected).length;
    }

    get selectedCountLabel() {
        const n = this.selectedCount;
        return `${n} recipient${n === 1 ? '' : 's'} selected`;
    }

    get statusCounts() {
        const list = this.activeTab === 'suppliers' ? this._suppliers : this._travellers;
        return {
            all: list.length,
            booked: list.filter((x) => x.statusKey === 'booked').length,
            request: list.filter((x) => x.statusKey === 'request').length,
            waiting: list.filter((x) => x.statusKey === 'waiting').length,
            cancelled: list.filter((x) => x.statusKey === 'cancelled').length
        };
    }

    handleTab(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }

    handleStatusTab(event) {
        this.statusFilter = event.currentTarget.dataset.status;
    }

    handleToggle(event) {
        const id = event.currentTarget.dataset.id;
        const toggle = (list) => list.map((r) => (r.id === id ? { ...r, selected: !r.selected } : r));
        if (this.activeTab === 'suppliers') {
            this._suppliers = toggle(this._suppliers);
        } else if (this.activeTab === 'contacts') {
            this._contacts = toggle(this._contacts);
        } else if (this.activeTab === 'agents') {
            this._agents = toggle(this._agents);
        } else {
            this._travellers = toggle(this._travellers);
        }
    }

    handleQuickSelect(event) {
        const mode = event.currentTarget.dataset.mode;
        const update = (list) => {
            if (mode === 'all')  return list.map((r) => ({ ...r, selected: true }));
            if (mode === 'none') return list.map((r) => ({ ...r, selected: false }));
            if (mode === 'lead') return list.map((r) => ({ ...r, selected: r.roleKey === 'lead' }));
            return list;
        };
        if (this.activeTab === 'suppliers') {
            this._suppliers = update(this._suppliers);
        } else if (this.activeTab === 'contacts') {
            this._contacts = update(this._contacts);
        } else if (this.activeTab === 'agents') {
            this._agents = update(this._agents);
        } else {
            this._travellers = update(this._travellers);
        }
    }

    normalizeApplyRow(row) {
        const email = (row.email || '').trim();
        return {
            id: row.id,
            contactId: row.contactId || null,
            audience: row.audience || 'travellers',
            name: row.name,
            email,
            initials: row.initials,
            role: row.role,
            roleKey: row.roleKey
        };
    }

    getActiveTabRecipients() {
        if (this.activeTab === 'suppliers') {
            return this._suppliers;
        }
        if (this.activeTab === 'contacts') {
            return this._contacts;
        }
        if (this.activeTab === 'agents') {
            return this._agents;
        }
        return this._travellers;
    }

    handleApply() {
        const selected = this.getActiveTabRecipients()
            .filter((r) => r.selected && (r.email || '').trim())
            .map((r) => this.normalizeApplyRow(r));
        if (!selected.length) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'No recipients selected',
                    message: 'Select at least one traveller, supplier, or contact with an email address.',
                    variant: 'warning'
                })
            );
            return;
        }
        this.dispatchEvent(new CustomEvent('apply', { detail: { recipients: selected } }));
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }

    computeInitials(name) {
        if (!name) return '--';
        const parts = name.trim().split(/\s+/);
        const a = parts[0]?.[0] || '-';
        const b = parts[1]?.[0] || parts[0]?.[0] || '-';
        return `${a}${b}`.toUpperCase();
    }

    applyPreselection() {
        const selectedIdSet = new Set((this._selectedIds || []).filter(Boolean));
        const selectedEmailSet = new Set(
            (this._selectedEmails || []).map((email) => String(email).trim().toLowerCase()).filter(Boolean)
        );
        const isPreselected = (row) => {
            if (!row) {
                return false;
            }
            if (row.contactId && selectedIdSet.has(row.contactId)) {
                return true;
            }
            if (row.id && selectedIdSet.has(row.id)) {
                return true;
            }
            const email = (row.email || '').trim().toLowerCase();
            return email && selectedEmailSet.has(email);
        };
        const mark = (list) => list.map((r) => ({ ...r, selected: isPreselected(r) }));
        this._travellers = mark(this._travellers);
        this._suppliers = mark(this._suppliers);
        this._contacts = mark(this._contacts);
        this._agents = mark(this._agents);
    }
}
