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
    @api summaryEmailCount;
    @api summaryWaCount;
    @api summaryIaCount;
    @api summaryTotalCount;
    @api refreshKey = 0;

    channelFilter = null;
    audienceFilter = null;
    statusGroupFilter = null;
    showFilterPanel = false;
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
        this._items = this.sortHistoryItems((data || []).map((row) => this.mapHistoryRow(row)));
        if (this.isDefaultFilters) {
            this._summaryCounts = {
                email: this._items.filter((x) => x.channel === 'email').length,
                wa: this._items.filter((x) => x.channel === 'wa').length,
                ia: this._items.filter((x) => x.channel === 'ia').length
            };
            this.syncSummaryCountsFromHub();
        } else {
            this.emailCount = this._summaryCounts.email;
            this.waCount = this._summaryCounts.wa;
            this.iaCount = this._summaryCounts.ia;
        }
    }

    syncSummaryCountsFromHub() {
        if (this.isHubMode && this.hasHubSummaryCounts) {
            this.emailCount = this.summaryEmailCount;
            this.waCount = this.summaryWaCount;
            this.iaCount = this.summaryIaCount;
            this._summaryCounts = {
                email: this.summaryEmailCount,
                wa: this.summaryWaCount,
                ia: this.summaryIaCount
            };
            return;
        }
        this.emailCount = this._summaryCounts.email;
        this.waCount = this._summaryCounts.wa;
        this.iaCount = this._summaryCounts.ia;
    }

    get hasHubSummaryCounts() {
        return (
            Number.isFinite(Number(this.summaryEmailCount)) &&
            Number.isFinite(Number(this.summaryWaCount)) &&
            Number.isFinite(Number(this.summaryIaCount))
        );
    }

    renderedCallback() {
        if (this.refreshKey !== this._lastRefreshKey) {
            this._lastRefreshKey = this.refreshKey;
            if (this._wiredHistoryResult) {
                refreshApex(this._wiredHistoryResult);
            }
        }
        if (this.isHubMode && this.isDefaultFilters && this.hasHubSummaryCounts) {
            this.syncSummaryCountsFromHub();
        }
    }

    get isHubMode() {
        return this.displayMode === 'hub';
    }

    get isHistoryOnly() {
        return this.displayMode === 'history';
    }

    get rootClass() {
        if (this.isHubMode) {
            return 'hub';
        }
        return this.showSidebar ? 'history-layout history-layout-filtered' : 'history-layout';
    }

    get showSidebar() {
        return this.isHubMode || this.showFilterPanel;
    }

    get hasActiveFilters() {
        return !this.isDefaultFilters || this.activeSidebar === 'drafts';
    }

    get filterButtonClass() {
        return this.showFilterPanel || this.hasActiveFilters ? 'btn btn-sec on' : 'btn btn-sec';
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

    handleToggleFilterPanel() {
        this.showFilterPanel = !this.showFilterPanel;
    }

    handleClearFilters() {
        this.activeSidebar = 'all';
        this.channelFilter = null;
        this.audienceFilter = null;
        this.statusGroupFilter = null;
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
            showDeliveryPill: true,
            deliveryPillClass: 'pill p-delivery-postmark',
            deliveryPillLabel: 'Postmark',
            attachmentsLabel: entry.attachments || 'None',
            emailHeading: entry.subject || 'Message Sent',
            emailBody: 'Message sent successfully.',
            hasAttachments: false,
            attachmentChips: [],
            messageId: entry.messageId,
            sortTimestamp: Date.now()
        };
        this._items = this.sortHistoryItems([newItem, ...this._items]);
        this.expandedId = newItem.id;
        if (this.isDefaultFilters) {
            this.emailCount += 1;
            this._summaryCounts = { ...this._summaryCounts, email: this.emailCount };
        }
    }

    mapHistoryRow(row) {
        const ch = row.channel === 'WhatsApp' ? 'wa' : row.channel === 'In-App' ? 'ia' : 'email';
        const isDraft = row.status === 'Draft';
        const statusPresentation = this.resolveStatusPresentation(row.status);
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
                : lastModifiedDate
                    ? lastModifiedDate.toLocaleString()
                    : 'Just now';
        const sortTimestamp = isDraft
            ? (lastModifiedDate?.getTime() ?? sentDate?.getTime() ?? 0)
            : (sentDate?.getTime() ?? lastModifiedDate?.getTime() ?? 0);
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
        const openCount = row.logOpenCount ?? row.openedCount ?? 0;
        const clickCount = row.logClickCount ?? 0;
        const trackingSummary = row.trackingSummary || '';
        const hasTracking =
            !isDraft &&
            (trackingSummary ||
                openCount > 0 ||
                clickCount > 0 ||
                row.deliveredAt ||
                row.bouncedAt ||
                row.bounceType);
        const deliveryPill = this.resolveDeliveryModePill(ch, isDraft, row.deliveryMode);
        return {
            id: row.id,
            channel: ch,
            subject: row.subject || 'Untitled message',
            who: recipientText,
            pillClass: statusPresentation.pillClass,
            pillLabel: row.status || 'Sent',
            when,
            dotColor: statusPresentation.dotColor,
            tagClass: ch === 'wa' ? 'tag tag-wa' : ch === 'ia' ? 'tag tag-ia' : 'tag tag-email',
            tagLabel: ch === 'wa' ? '💬 WhatsApp' : ch === 'ia' ? '🔔 In-App' : '✉ Email',
            isDraft,
            lastEdited,
            statusLabel: `● ${row.status || 'Sent'}`,
            statusClass: statusPresentation.detailClass,
            statusStyle: statusPresentation.detailStyle,
            sentAt: isDraft ? when : sentDate ? sentDate.toLocaleString() : when,
            sortTimestamp,
            sentBy: row.sentBy || 'System',
            fromDisplay: row.fromDisplay || this.formatFromFallback(row.sentBy, row.fromEmail),
            recipientLabel: row.recipientCount === 1 ? 'Recipient' : 'Recipients',
            recipients: recipientNames.length ? recipientNames.join('\n') : 'No recipients',
            delivery: this.buildDeliveryLabel(row),
            attachmentsLabel: row.attachmentSummary || 'None',
            emailHeading: row.subject || 'Communication',
            emailBody: this.stripHtml(row.bodyHtml) || 'No preview available.',
            hasAttachments: (row.attachmentCount || 0) > 0,
            attachmentChips: this.buildAttachmentChips(row.attachmentSummary),
            hasTracking,
            trackingSummary,
            openCountLabel: openCount > 0 ? `${openCount} open${openCount === 1 ? '' : 's'}` : null,
            clickCountLabel: clickCount > 0 ? `${clickCount} click${clickCount === 1 ? '' : 's'}` : null,
            bounceLabel: row.bounceType
                ? `${row.bounceType}${row.bounceDescription ? ` — ${row.bounceDescription}` : ''}`
                : row.bounceDescription || null,
            messageId: row.messageId || null,
            showDeliveryPill: deliveryPill.show,
            deliveryPillClass: deliveryPill.pillClass,
            deliveryPillLabel: deliveryPill.pillLabel
        };
    }

    resolveDeliveryModePill(channel, isDraft, deliveryMode) {
        if (channel !== 'email' || isDraft) {
            return { show: false, pillClass: '', pillLabel: '' };
        }
        const normalized = (deliveryMode || 'postmark').trim().toLowerCase();
        if (
            normalized === 'native' ||
            normalized === 'salesforce' ||
            normalized === 'sf' ||
            normalized.includes('native')
        ) {
            return {
                show: true,
                pillClass: 'pill p-delivery-native',
                pillLabel: 'Native'
            };
        }
        return {
            show: true,
            pillClass: 'pill p-delivery-postmark',
            pillLabel: 'Postmark'
        };
    }

    resolveStatusPresentation(status) {
        const normalized = (status || 'sent').trim().toLowerCase();
        const detailKey = normalized.replace(/\s+/g, '-');
        const presets = {
            draft: {
                pillClass: 'pill p-draft',
                dotColor: 'var(--t4)',
                detailClass: `tl-dm-status ${detailKey}`,
                detailStyle: ''
            },
            sent: {
                pillClass: 'pill p-sent',
                dotColor: 'var(--ok)',
                detailClass: `tl-dm-status ${detailKey}`,
                detailStyle: ''
            },
            delivered: {
                pillClass: 'pill p-delivered',
                dotColor: 'var(--go)',
                detailClass: `tl-dm-status ${detailKey}`,
                detailStyle: ''
            },
            opened: {
                pillClass: 'pill p-opened',
                dotColor: 'var(--info)',
                detailClass: `tl-dm-status ${detailKey}`,
                detailStyle: ''
            },
            bounced: {
                pillClass: 'pill p-bounced',
                dotColor: 'var(--err)',
                detailClass: `tl-dm-status ${detailKey}`,
                detailStyle: ''
            },
            'spam complaint': {
                pillClass: 'pill p-spam',
                dotColor: 'var(--warn)',
                detailClass: `tl-dm-status ${detailKey}`,
                detailStyle: ''
            },
            received: {
                pillClass: 'pill p-received',
                dotColor: 'var(--ok)',
                detailClass: `tl-dm-status ${detailKey}`,
                detailStyle: ''
            },
            failed: {
                pillClass: 'pill p-failed',
                dotColor: 'var(--err)',
                detailClass: `tl-dm-status ${detailKey}`,
                detailStyle: ''
            }
        };
        return presets[normalized] || presets.sent;
    }

    buildDeliveryLabel(row) {
        const mode = row.deliveryMode || 'Postmark';
        const delivered = row.deliveredCount || 0;
        const opened = row.openedCount || 0;
        const total = row.recipientCount || 0;
        if (total > 0 && (delivered > 0 || opened > 0)) {
            return `${mode} · ${delivered}/${total} delivered · ${opened} opened`;
        }
        if (row.trackingSummary) {
            return `${mode} · ${row.trackingSummary}`;
        }
        return mode;
    }

    formatFromFallback(sentBy, fromEmail) {
        const name = (sentBy || '').trim();
        const email = (fromEmail || '').trim();
        if (name && email) {
            return `${name} <${email}>`;
        }
        return email || name || 'Unknown sender';
    }

    stripHtml(content) {
        if (!content) {
            return '';
        }
        return content.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
    }

    sortHistoryItems(items) {
        return [...items].sort((a, b) => (b.sortTimestamp || 0) - (a.sortTimestamp || 0));
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
