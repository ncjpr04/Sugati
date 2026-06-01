import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import getHistory from '@salesforce/apex/SugatiCommunicationHubController.getHistory';

const DEFAULT_ITEMS = [];

export default class SugatiCommunicationHistory extends LightningElement {
    @api displayMode = 'hub';
    @api tripTitle = '';
    @api tripSubtitle = '';
    @api opportunityId;
    @api draftCount = 0;
    @api refreshKey = 0;

    channelFilter = null;
    audienceFilter = null;
    statusGroupFilter = null;
    expandedId = null;
    activeSidebar = 'all';
    _items = DEFAULT_ITEMS.map((i) => ({ ...i }));

    emailCount = 0;
    waCount = 0;
    iaCount = 0;
    _wiredHistoryResult;
    _summaryCounts = { email: 0, wa: 0, ia: 0 };
    _lastRefreshKey = -1;

    @wire(getHistory, {
        opportunityId: '$opportunityId',
        channelFilter: '$channelFilterParam',
        statusFilter: '$statusFilterParam',
        audienceFilter: '$audienceFilterParam',
        statusGroupFilter: '$statusGroupFilterParam'
    })
    wiredHistory(result) {
        this._wiredHistoryResult = result;
        const data = result?.data;
        this._items = (data || []).map((row) => this.mapHistoryRow(row));
        if (this.isDefaultFilters) {
            this._summaryCounts = {
                email: this._items.filter((x) => x.channel === 'email').length,
                wa: this._items.filter((x) => x.channel === 'wa').length,
                ia: this._items.filter((x) => x.channel === 'ia').length
            };
            this.emailCount = this._summaryCounts.email;
            this.waCount = this._summaryCounts.wa;
            this.iaCount = this._summaryCounts.ia;
        } else {
            this.emailCount = this._summaryCounts.email;
            this.waCount = this._summaryCounts.wa;
            this.iaCount = this._summaryCounts.ia;
        }
    }

    renderedCallback() {
        if (this.refreshKey !== this._lastRefreshKey) {
            this._lastRefreshKey = this.refreshKey;
            if (this._wiredHistoryResult) {
                refreshApex(this._wiredHistoryResult);
            }
        }
    }

    get isHubMode() {
        return this.displayMode === 'hub';
    }

    get isHistoryOnly() {
        return this.displayMode === 'history';
    }

    get rootClass() {
        return this.isHubMode ? 'hub' : 'history-layout';
    }

    get isDefaultFilters() {
        return (
            this.activeSidebar === 'all' &&
            !this.channelFilter &&
            !this.audienceFilter &&
            !this.statusGroupFilter
        );
    }

    get hubTitle() {
        if (this.isHistoryOnly) {
            return 'Communication History';
        }
        if (this.activeSidebar === 'drafts') {
            return 'Drafts';
        }
        if (this.channelFilter === 'email') {
            return 'Email';
        }
        if (this.channelFilter === 'wa') {
            return 'WhatsApp';
        }
        if (this.channelFilter === 'ia') {
            return 'In-App';
        }
        if (this.audienceFilter === 'travellers') {
            return 'Travellers';
        }
        if (this.audienceFilter === 'suppliers') {
            return 'Suppliers & Agents';
        }
        if (this.statusGroupFilter === 'delivered_opened') {
            return 'Delivered & Opened';
        }
        if (this.statusGroupFilter === 'failed_bounced') {
            return 'Failed & Bounced';
        }
        return 'All Communications';
    }

    get timelineItems() {
        return this._items.map((item) => ({
            ...item,
            isExpanded: this.expandedId === item.id,
            dotStyle: `background:${item.dotColor}`,
            rowClass: this._buildRowClass(item),
            buttonLabel: this.expandedId === item.id ? 'Close' : 'View',
            isEmail: item.channel === 'email',
            isWa: item.channel === 'wa',
            isIa: item.channel === 'ia'
        }));
    }

    get hasTimelineItems() {
        return this.timelineItems.length > 0;
    }

    get channelFilterParam() {
        if (this.channelFilter === 'wa') {
            return 'WhatsApp';
        }
        if (this.channelFilter === 'ia') {
            return 'In-App';
        }
        if (this.channelFilter === 'email') {
            return 'Email';
        }
        return null;
    }

    get statusFilterParam() {
        return this.activeSidebar === 'drafts' ? 'Draft' : null;
    }

    get audienceFilterParam() {
        return this.audienceFilter || null;
    }

    get statusGroupFilterParam() {
        return this.statusGroupFilter || null;
    }

    get draftBadgeCount() {
        const n = Number(this.draftCount);
        return Number.isFinite(n) && n > 0 ? n : 0;
    }

    get showDraftBadge() {
        return this.draftBadgeCount > 0;
    }

    get allSidebarClass() {
        return this.activeSidebar === 'all' && !this.audienceFilter && !this.statusGroupFilter ? 'sb-item on' : 'sb-item';
    }

    get draftsSidebarClass() {
        return this.activeSidebar === 'drafts' ? 'sb-item on' : 'sb-item';
    }

    get travellersSidebarClass() {
        return this.audienceFilter === 'travellers' ? 'sb-item on' : 'sb-item';
    }

    get suppliersSidebarClass() {
        return this.audienceFilter === 'suppliers' ? 'sb-item on' : 'sb-item';
    }

    get deliveredOpenedClass() {
        return this.statusGroupFilter === 'delivered_opened' ? 'sb-item on' : 'sb-item';
    }

    get failedBouncedClass() {
        return this.statusGroupFilter === 'failed_bounced' ? 'sb-item on' : 'sb-item';
    }

    get emailPillClass() {
        return this.channelFilter === 'email' ? 'sb-ch-pill on' : 'sb-ch-pill';
    }

    get waPillClass() {
        return this.channelFilter === 'wa' ? 'sb-ch-pill on' : 'sb-ch-pill';
    }

    get iaPillClass() {
        return this.channelFilter === 'ia' ? 'sb-ch-pill on' : 'sb-ch-pill';
    }

    _buildRowClass(item) {
        let cls = 'tl-item';
        if (this.expandedId === item.id) {
            cls += ' expanded';
        }
        if (item.isNew) {
            cls += ' new-entry';
        }
        return cls;
    }

    handleRowClick(event) {
        if (event.target.classList.contains('tl-act')) {
            return;
        }
        const id = event.currentTarget.dataset.id;
        this.expandedId = this.expandedId === id ? null : id;
    }

    handleToggle(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this.expandedId = this.expandedId === id ? null : id;
    }

    stopProp(event) {
        event.stopPropagation();
    }

    handleSidebarClick(event) {
        const key = event.currentTarget.dataset.key;
        if (key === 'drafts') {
            this.activeSidebar = 'drafts';
            this.audienceFilter = null;
            this.statusGroupFilter = null;
            return;
        }
        this.activeSidebar = 'all';
        this.audienceFilter = null;
        this.statusGroupFilter = null;
        this.channelFilter = null;
    }

    handleChannelPill(event) {
        event.stopPropagation();
        const ch = event.currentTarget.dataset.channel;
        this.activeSidebar = 'all';
        this.statusGroupFilter = null;
        this.channelFilter = this.channelFilter === ch ? null : ch;
    }

    handleAudienceClick(event) {
        const key = event.currentTarget.dataset.key;
        this.activeSidebar = 'all';
        this.statusGroupFilter = null;
        this.audienceFilter = this.audienceFilter === key ? null : key;
    }

    handleStatusGroupClick(event) {
        const key = event.currentTarget.dataset.key;
        this.activeSidebar = 'all';
        this.audienceFilter = null;
        this.statusGroupFilter = this.statusGroupFilter === key ? null : key;
    }

    @api
    async refreshHistory() {
        if (this._wiredHistoryResult) {
            await refreshApex(this._wiredHistoryResult);
        }
    }

    handleContinueDraft(event) {
        event.stopPropagation();
        const commLogId = event.currentTarget.dataset.id;
        this.dispatchEvent(
            new CustomEvent('continuedraft', {
                detail: { commLogId }
            })
        );
    }

    handleChannelCard(event) {
        event.stopPropagation();
        this.dispatchEvent(
            new CustomEvent('channelnav', {
                detail: { channel: event.currentTarget.dataset.channel }
            })
        );
    }

    @api
    addSentEntry(entry) {
        const newItem = {
            id: `tl-${Date.now()}`,
            channel: 'email',
            subject: entry.subject || 'Your Tokyo Honeymoon — Final Itinerary',
            who: entry.who || 'Recipients',
            pillClass: 'pill p-go',
            pillLabel: '✓ Sent',
            when: 'Today',
            dotColor: 'var(--ok)',
            tagClass: 'tag tag-email',
            tagLabel: '✉ Email',
            isDraft: false,
            isNew: true,
            statusLabel: '● Sent',
            statusClass: 'tl-dm-status opened',
            statusStyle: '',
            sentAt: entry.sentAt || 'Just now',
            sentBy: 'System',
            recipientLabel: 'Recipients',
            recipients: entry.recipients || 'Recipients',
            delivery: 'Postmark',
            attachmentsLabel: entry.attachments || 'None',
            emailHeading: entry.subject || 'Message Sent',
            emailBody: 'Message sent successfully.',
            emailCta: 'View Online',
            hasAttachments: false,
            attachmentChips: [],
            messageId: entry.messageId
        };
        this._items = [newItem, ...this._items];
        this.expandedId = newItem.id;
        if (this.isDefaultFilters) {
            this.emailCount += 1;
            this._summaryCounts = { ...this._summaryCounts, email: this.emailCount };
        }
    }

    mapHistoryRow(row) {
        const ch = row.channel === 'WhatsApp' ? 'wa' : row.channel === 'In-App' ? 'ia' : 'email';
        const isDraft = row.status === 'Draft';
        const statusLower = (row.status || '').toLowerCase();
        const sentDate = row.sentAt ? new Date(row.sentAt) : null;
        const lastModifiedDate = row.lastModifiedAt ? new Date(row.lastModifiedAt) : null;
        const when = isDraft
            ? lastModifiedDate
                ? lastModifiedDate.toLocaleString()
                : sentDate
                    ? sentDate.toLocaleString()
                    : 'Just now'
            : sentDate
                ? sentDate.toLocaleString()
                : 'Just now';
        const lastEdited = lastModifiedDate
            ? lastModifiedDate.toLocaleString()
            : sentDate
                ? sentDate.toLocaleString()
                : '—';
        const recipientNames = (row.who || '')
            .split('\n')
            .map((name) => (name || '').trim())
            .filter(Boolean);
        const recipientText = recipientNames.length ? recipientNames.join(', ') : 'No recipients';
        return {
            id: row.id,
            channel: ch,
            subject: row.subject || 'Untitled message',
            who: recipientText,
            pillClass: ch === 'wa' ? 'pill p-wa' : ch === 'ia' ? 'pill p-ia' : 'pill p-go',
            pillLabel: row.status || 'Sent',
            when,
            dotColor: ch === 'wa' ? 'var(--ch-wa)' : ch === 'ia' ? 'var(--ch-ia)' : 'var(--go)',
            tagClass: ch === 'wa' ? 'tag tag-wa' : ch === 'ia' ? 'tag tag-ia' : 'tag tag-email',
            tagLabel: ch === 'wa' ? '💬 WhatsApp' : ch === 'ia' ? '🔔 In-App' : '✉ Email',
            isDraft,
            lastEdited,
            statusLabel: `● ${row.status || 'Sent'}`,
            statusClass: `tl-dm-status ${statusLower}`,
            statusStyle: '',
            sentAt: when,
            sentBy: row.sentBy || 'System',
            recipientLabel: row.recipientCount === 1 ? 'Recipient' : 'Recipients',
            recipients: recipientNames.length ? recipientNames.join('\n') : 'No recipients',
            delivery: row.deliveryMode || 'Postmark',
            attachmentsLabel: row.attachmentSummary || 'None',
            emailHeading: row.subject || 'Communication',
            emailBody: this.stripHtml(row.bodyHtml) || 'No preview available.',
            emailCta: 'Open',
            hasAttachments: (row.attachmentCount || 0) > 0,
            attachmentChips: this.buildAttachmentChips(row.attachmentSummary)
        };
    }

    stripHtml(content) {
        if (!content) {
            return '';
        }
        return content.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
    }

    buildAttachmentChips(summary) {
        if (!summary || summary === 'None') {
            return [];
        }
        return summary.split(',').map((name, index) => {
            const trimmed = (name || '').trim();
            const isPdf = trimmed.toLowerCase().endsWith('.pdf');
            return {
                id: `att-chip-${index}`,
                name: trimmed,
                type: isPdf ? 'PDF' : 'GEN',
                iconClass: isPdf ? 'tl-att-chip ic-pdf' : 'tl-att-chip ic-gen'
            };
        });
    }
}
