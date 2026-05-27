import { LightningElement, api } from 'lwc';

const TRAVELLERS = [
    { id: 'r1', initials: 'HY', name: 'Hiroshi Yamamura', email: 'hiroshi@yamamura.com', role: 'Lead Booker', roleKey: 'lead', status: 'Booked', statusKey: 'booked', avClass: 'av-gold', selected: true },
    { id: 'r2', initials: 'AY', name: 'Akemi Yamamura', email: 'akemi@yamamura.com', role: 'Traveller', roleKey: 'traveller', status: 'Booked', statusKey: 'booked', avClass: 'av-gold', selected: true },
    { id: 'r3', initials: 'KY', name: 'Kenji Yamamura', email: 'kenji@yamamura.com', role: 'Traveller', roleKey: 'traveller', status: 'Booked', statusKey: 'booked', avClass: 'av-blue', selected: false },
    { id: 'r4', initials: 'SN', name: 'Sakura Nakamura', email: 's.nakamura@email.com', role: 'Lead Booker', roleKey: 'lead', status: 'On Request', statusKey: 'request', avClass: 'av-ok', selected: false },
    { id: 'r5', initials: 'TK', name: 'Takeshi Kobayashi', email: 't.kobayashi@email.com', role: 'Lead Booker', roleKey: 'lead', status: 'Waiting List', statusKey: 'waiting', avClass: 'av-warn', selected: false },
    { id: 'r6', initials: 'YK', name: 'Yuki Kobayashi', email: 'y.kobayashi@email.com', role: 'Traveller', roleKey: 'traveller', status: 'Waiting List', statusKey: 'waiting', avClass: 'av-warn', selected: false },
    { id: 'r7', initials: 'MT', name: 'Mika Tanaka', email: 'm.tanaka@email.com', role: 'Lead Booker', roleKey: 'lead', status: 'Cancelled', statusKey: 'cancelled', avClass: 'av-err', selected: false }
];

const SUPPLIERS = [
    { id: 's1', initials: 'PH', name: 'Park Hyatt Tokyo', email: 'reservations@parkhyatt.co.jp', role: 'Hotel', roleKey: 'supplier', status: 'Confirmed', statusKey: 'confirmed', avClass: 'av-blue', selected: false },
    { id: 's2', initials: 'WT', name: 'Wayo Tours', email: 'bookings@wayotours.jp', role: 'Guide', roleKey: 'supplier', status: 'Confirmed', statusKey: 'confirmed', avClass: 'av-blue', selected: false },
    { id: 's3', initials: 'JA', name: 'JAL Airlines', email: 'groups@jal.co.jp', role: 'Transport', roleKey: 'supplier', status: 'Confirmed', statusKey: 'confirmed', avClass: 'av-blue', selected: false },
    { id: 's4', initials: 'RH', name: 'Ryokan Hoshino', email: 'info@hoshinoresorts.com', role: 'Hotel', roleKey: 'supplier', status: 'Confirmed', statusKey: 'confirmed', avClass: 'av-blue', selected: false }
];

const STATUS_COUNTS = { all: 7, booked: 3, request: 1, waiting: 2, cancelled: 1 };

export default class SugatiCommunicationRecipientSelector extends LightningElement {
    @api selectedIds = [];

    activeTab = 'travellers';
    statusFilter = 'all';
    _travellers = TRAVELLERS.map((r) => ({ ...r }));
    _suppliers = SUPPLIERS.map((r) => ({ ...r }));

    get tabs() {
        return [
            { id: 'travellers', label: '🧳 Travellers', count: 7, className: this.activeTab === 'travellers' ? 'rec-aud-tab on' : 'rec-aud-tab' },
            { id: 'agents',     label: '🏢 Agent',       count: null, className: this.activeTab === 'agents' ? 'rec-aud-tab on' : 'rec-aud-tab' },
            { id: 'suppliers',  label: '🏨 Suppliers',   count: 4, className: this.activeTab === 'suppliers' ? 'rec-aud-tab on' : 'rec-aud-tab' },
            { id: 'contacts',   label: '📋 Sup. Contacts', count: 6, className: this.activeTab === 'contacts' ? 'rec-aud-tab on' : 'rec-aud-tab' }
        ];
    }

    get statusTabs() {
        return [
            { id: 'all',       label: 'All',          count: STATUS_COUNTS.all,       countClass: 'rec-stab-n',           className: this.statusFilter === 'all'       ? 'rec-stab on' : 'rec-stab' },
            { id: 'booked',    label: 'Booked',       count: STATUS_COUNTS.booked,    countClass: 'rec-stab-n booked',    className: this.statusFilter === 'booked'    ? 'rec-stab on' : 'rec-stab' },
            { id: 'request',   label: 'On Request',   count: STATUS_COUNTS.request,   countClass: 'rec-stab-n request',   className: this.statusFilter === 'request'   ? 'rec-stab on' : 'rec-stab' },
            { id: 'waiting',   label: 'Waiting List', count: STATUS_COUNTS.waiting,   countClass: 'rec-stab-n waiting',   className: this.statusFilter === 'waiting'   ? 'rec-stab on' : 'rec-stab' },
            { id: 'cancelled', label: 'Cancelled',    count: STATUS_COUNTS.cancelled, countClass: 'rec-stab-n cancelled', className: this.statusFilter === 'cancelled' ? 'rec-stab on' : 'rec-stab' }
        ];
    }

    get showTravellers() { return this.activeTab === 'travellers'; }
    get showSuppliers()  { return this.activeTab === 'suppliers'; }
    get showAgentsEmpty(){ return this.activeTab === 'agents'; }
    get showContacts()   { return this.activeTab === 'contacts'; }

    get visibleRecipients() {
        const list = this.activeTab === 'suppliers' ? this._suppliers : this._travellers;
        return list
            .filter((r) => {
                if (this.statusFilter === 'all') return true;
                return r.statusKey === this.statusFilter;
            })
            .map((r) => ({
                ...r,
                rowClass: r.selected ? 'rec-item sel' : 'rec-item',
                cbClass: r.selected ? 'rec-cb on' : 'rec-cb',
                roleClass: `rec-role-badge ${r.roleKey}`,
                statusClass: `rec-status-badge ${r.statusKey}`
            }));
    }

    get selectedCount() {
        return [...this._travellers, ...this._suppliers].filter((r) => r.selected).length;
    }

    get selectedCountLabel() {
        const n = this.selectedCount;
        return `${n} recipient${n === 1 ? '' : 's'} selected`;
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
        this._travellers = toggle(this._travellers);
        this._suppliers = toggle(this._suppliers);
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
        } else {
            this._travellers = update(this._travellers);
        }
    }

    handleApply() {
        const selected = [...this._travellers, ...this._suppliers].filter((r) => r.selected);
        this.dispatchEvent(new CustomEvent('apply', { detail: { recipients: selected } }));
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back'));
    }
}
