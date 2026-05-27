import { LightningElement, api } from 'lwc';

const DEFAULT_CHIPS = [
    { id: 'c1', initials: 'HY', name: 'Hiroshi Yamamura', email: 'hiroshi@yamamura.com' },
    { id: 'c2', initials: 'AY', name: 'Akemi Yamamura', email: 'akemi@yamamura.com' }
];

const TEMPLATE_ITEMS = [
    { id: 't1', name: 'Pre-trip Welcome Pack', meta: 'Traveller · B2C', folder: 'traveller', stage: 'pre-dep', suggested: true, active: true },
    { id: 't2', name: 'Final Itinerary & Documents', meta: 'Traveller · B2C', folder: 'traveller', stage: 'pre-dep', suggested: true, active: false },
    { id: 't3', name: 'Booking Confirmation', meta: 'Traveller · B2C', folder: 'traveller', stage: 'booked', suggested: false, active: false },
    { id: 't4', name: 'Balance Due Reminder', meta: 'Traveller · B2C', folder: 'traveller', stage: 'booked', suggested: false, active: false },
    { id: 't5', name: 'Supplier Booking Request', meta: 'Supplier · Ops', folder: 'supplier', stage: 'booked', suggested: false, active: false }
];

const ATTACHMENTS = [
    { id: 'a1', name: 'Tokyo Itinerary Final.pdf', meta: 'Opportunity file · 2.4 MB', type: 'pdf', checked: true },
    { id: 'a2', name: 'Japan Entry Requirements.pdf', meta: 'Country file · Japan', type: 'gen', checked: true },
    { id: 'a3', name: 'Invoice #INV-2026-0412.pdf', meta: 'Generate on send', type: 'gen', checked: true, ai: true }
];

const SUBJECT_MAP = {
    'Pre-trip Welcome Pack': 'Your Tokyo Honeymoon — Pre-trip Welcome & Itinerary',
    'Final Itinerary & Documents': 'Your Tokyo Honeymoon — Final Itinerary & Arrival Details',
    'Booking Confirmation': 'Your Booking is Confirmed — Tokyo Honeymoon 2026',
    'Balance Due Reminder': 'Balance Payment Due — Tokyo Honeymoon 2026',
    'Supplier Booking Request': 'Booking Request — Tokyo Honeymoon 2026'
};

export default class SugatiCommunicationEmailComposer extends LightningElement {
    @api tripName = 'Tokyo Honeymoon 2026';
    @api stageLabel = 'Pre-Departure';
    @api openWithTemplatePicker = false;

    toChips = [...DEFAULT_CHIPS];
    ccChips = [];
    subject = 'Your Tokyo Honeymoon — Final Itinerary & Arrival Details';
    activeTemplateName = 'Pre-trip Welcome Pack';
    activeTemplateMeta = 'Traveller · B2C';
    templateSearch = '';
    activeFolder = 'all';
    deliveryMode = 'postmark';
    showAiAssist = false;
    attCount = 3;
    _pickerOpenRequested = false;

    _templates = TEMPLATE_ITEMS.map((t) => ({ ...t }));
    _attachments = ATTACHMENTS.map((a) => ({ ...a }));

    connectedCallback() {
        if (this.openWithTemplatePicker && !this._pickerOpenRequested) {
            this._pickerOpenRequested = true;
            this.dispatchEvent(
                new CustomEvent('opentemplates', {
                    bubbles: true,
                    composed: true
                })
            );
        }
    }

    get railRecipients() {
        return this.toChips.map((c) => ({
            ...c,
            role: c.role || 'Traveller'
        }));
    }

    get folderTabs() {
        const folders = ['all', 'traveller', 'supplier', 'ops', 'compliance', 'finance'];
        const labels = { all: 'All', traveller: 'Traveller', supplier: 'Supplier', ops: 'Ops', compliance: 'Compliance', finance: 'Finance' };
        return folders.map((f) => ({
            id: f,
            label: labels[f],
            className: f === this.activeFolder ? 'tmpl-ftab on' : 'tmpl-ftab'
        }));
    }

    get filteredTemplates() {
        const q = (this.templateSearch || '').toLowerCase();
        return this._templates
            .filter((t) => this.activeFolder === 'all' || t.folder === this.activeFolder)
            .filter((t) => !q || t.name.toLowerCase().includes(q))
            .map((t) => ({
                ...t,
                itemClass: t.active ? 'tmpl-item on' : 'tmpl-item',
                stageClass: `tmpl-stage-badge ${t.stage}`
            }));
    }

    get attachments() {
        return this._attachments.map((a) => ({
            ...a,
            cbClass: a.checked ? 'att-cb ck' : 'att-cb',
            icClass: a.type === 'pdf' ? 'att-ic ic-pdf' : 'att-ic ic-gen'
        }));
    }

    get deliveryPostmarkClass() {
        return this.deliveryMode === 'postmark' ? 'del-opt on' : 'del-opt';
    }

    get deliveryNativeClass() {
        return this.deliveryMode === 'native' ? 'del-opt on' : 'del-opt';
    }

    get attCountLabel() {
        return `${this.attCount} selected`;
    }

    get recipientSummary() {
        return this.toChips.map((c) => c.name.split(' ')[0]).join(' & ') || 'Recipients';
    }

    @api
    setRecipients(recipients) {
        if (recipients && recipients.length) {
            this.toChips = recipients.map((r, i) => ({
                id: r.id || `r-${i}`,
                initials: r.initials,
                name: r.name,
                email: r.email,
                role: r.role
            }));
        }
    }

    handleRemoveChip(event) {
        const email = event.currentTarget.dataset.email;
        this.toChips = this.toChips.filter((c) => c.email !== email);
    }

    handleFolderTab(event) {
        this.activeFolder = event.currentTarget.dataset.folder;
        this.templateSearch = '';
    }

    handleTemplateSearch(event) {
        this.templateSearch = event.target.value;
    }

    handleTemplateActivate(event) {
        const name = event.currentTarget.dataset.name;
        this._templates = this._templates.map((t) => ({ ...t, active: t.name === name }));
        this.activeTemplateName = name;
        const active = this._templates.find((t) => t.active);
        this.activeTemplateMeta = active ? active.meta : '';
        if (SUBJECT_MAP[name]) {
            this.subject = SUBJECT_MAP[name];
        }
    }

    handleAttachmentToggle(event) {
        const id = event.currentTarget.dataset.id;
        this._attachments = this._attachments.map((a) => {
            if (a.id === id) {
                return { ...a, checked: !a.checked };
            }
            return a;
        });
        this.attCount = this._attachments.filter((a) => a.checked).length;
    }

    handleDeliveryPostmark() {
        this.deliveryMode = 'postmark';
    }

    handleDeliveryNative() {
        this.deliveryMode = 'native';
    }

    handleOpenTemplates() {
        this.dispatchEvent(
            new CustomEvent('opentemplates', {
                bubbles: true,
                composed: true
            })
        );
    }

    @api
    applyTemplateSelection(detail) {
        const { name } = detail || {};
        if (name) {
            this.handleTemplateActivate({ currentTarget: { dataset: { name } } });
        }
    }

    handleOpenMerge() {
        this.dispatchEvent(
            new CustomEvent('navigatetokens', {
                bubbles: true,
                composed: true
            })
        );
    }

    @api
    insertToken(token) {
        const editor = this.template.querySelector('.editor-body');
        if (!editor || !token) return;

        editor.focus();

        const selection = window.getSelection && window.getSelection();
        if (selection && selection.rangeCount) {
            const range = selection.getRangeAt(0);
            const node = document.createTextNode(token);
            range.insertNode(node);
            range.setStartAfter(node);
            range.setEndAfter(node);
            selection.removeAllRanges();
            selection.addRange(range);
        } else {
            editor.appendChild(document.createTextNode(token));
        }
    }

    handleOpenAi() {
        this.showAiAssist = true;
    }

    handleCloseAi() {
        this.showAiAssist = false;
    }

    handleAiApply(event) {
        const { mode, body, subjects } = event.detail;
        if (mode === 'subject' && subjects && subjects.length) {
            this.subject = subjects[0];
        } else if (body) {
            const editor = this.template.querySelector('.editor-body');
            if (editor) {
                editor.innerText = body;
            }
        }
        this.showAiAssist = false;
    }

    handleSubjectChange(event) {
        this.subject = event.target.value;
    }

    handlePreview() {
        this.dispatchEvent(
            new CustomEvent('navigatepreview', {
                detail: {
                    channel: 'email',
                    subject: this.subject,
                    recipients: this.toChips,
                    deliveryMode: this.deliveryMode,
                    templateName: this.activeTemplateName
                }
            })
        );
    }

    handleRecipientsNav() {
        this.dispatchEvent(new CustomEvent('navigaterecipients'));
    }
}
