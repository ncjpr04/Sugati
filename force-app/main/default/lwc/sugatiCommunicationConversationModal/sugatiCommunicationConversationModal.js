import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class SugatiCommunicationConversationModal extends NavigationMixin(LightningElement) {
    @api isOpen = false;
    @api isLoading = false;

    subject = 'Conversation';
    threadMeta = {};
    _messages = [];
    expandedId = null;
    expandAllActive = false;
    collapsedAllActive = false;
    copyFeedback = '';
    _escapeHandler;
    _pendingScrollToLatest = false;

    connectedCallback() {
        this._escapeHandler = (event) => {
            if (event.key === 'Escape' && this.isOpen) {
                this.handleClose();
            }
        };
        window.addEventListener('keydown', this._escapeHandler);
    }

    disconnectedCallback() {
        if (this._escapeHandler) {
            window.removeEventListener('keydown', this._escapeHandler);
        }
    }

    @api
    setThread(thread) {
        if (!thread) {
            this.resetThread();
            return;
        }
        this.subject = thread.subject || 'Conversation';
        this.threadMeta = {
            threadRootId: thread.threadRootId,
            rootStatus: thread.rootStatus,
            rootDeliveryLabel: thread.rootDeliveryLabel,
            rootMessageId: thread.rootMessageId,
            rootFromParty: thread.rootFromParty || {},
            rootToParties: thread.rootToParties || [],
            inboundCount: thread.inboundCount || 0,
            outboundCount: thread.outboundCount || 0,
            threadStartedLabel: thread.threadStartedLabel,
            threadLastActivityLabel: thread.threadLastActivityLabel
        };
        this._messages = (thread.messages || []).map((row, index) => this.decorateMessage(row, index));
        this.expandAllActive = false;
        this.collapsedAllActive = false;
        this.expandedId = this._messages.length ? this._messages[this._messages.length - 1].key : null;
        this.copyFeedback = '';
        this._pendingScrollToLatest = true;
    }

    resetThread() {
        this._messages = [];
        this.threadMeta = {};
        this.subject = 'Conversation';
        this.expandedId = null;
        this.expandAllActive = false;
        this.collapsedAllActive = false;
        this.copyFeedback = '';
        this._pendingScrollToLatest = false;
    }

    decorateMessage(row, index) {
        const name = (row.senderName || row.senderDisplay || 'Unknown').trim();
        const attachmentChips = this.buildAttachmentChips(row.attachments);
        return {
            ...row,
            key: row.id,
            index: index + 1,
            initials: this.buildInitials(name),
            senderLine: row.senderVia ? `${name} via ${row.senderVia}` : row.senderDisplay || name,
            recipientLine: row.recipientSummary ? `to ${row.recipientSummary}` : 'to me',
            timeLabel: this.buildTimeLabel(row),
            fullTimeLabel: row.sentAtFullLabel || this.buildTimeLabel(row),
            statusClass: this.buildStatusClass(row.status),
            statusLabel: row.status || (row.isOutbound ? 'Sent' : 'Received'),
            rootBadgeClass: row.isThreadRoot ? 'conv-root-badge' : 'conv-root-badge hidden',
            rootBadgeLabel: row.isThreadRoot ? 'Original' : '',
            deliveryLabel: this.formatDeliveryLabel(row.deliveryMode),
            showDelivery: !!row.isOutbound,
            hasAttachments: (row.attachmentCount || 0) > 0,
            attachmentChips,
            showMessageId: !!row.messageId
        };
    }

    buildAttachmentChips(attachments) {
        if (!attachments || !attachments.length) {
            return [];
        }
        return attachments.map((att, chipIndex) => {
            const name = (att.name || 'Attachment').trim();
            const storageKind = att.storageKind || (att.contentDocumentId ? 'ContentDocument' : 'Attachment');
            const contentDocumentId = att.contentDocumentId || null;
            const attachmentRecordId = att.attachmentRecordId || null;
            const fileType = (att.fileType || '').toLowerCase();
            return {
                id: contentDocumentId || attachmentRecordId || `att-${chipIndex}`,
                name,
                meta: att.meta || '',
                storageKind,
                contentDocumentId,
                attachmentRecordId,
                isPdf: fileType === 'pdf' || name.toLowerCase().endsWith('.pdf'),
                canOpen: !!(contentDocumentId || attachmentRecordId)
            };
        });
    }

    formatDeliveryLabel(deliveryMode) {
        const normalized = (deliveryMode || 'postmark').trim().toLowerCase();
        if (normalized === 'native' || normalized.includes('native') || normalized === 'salesforce') {
            return 'Native';
        }
        return 'Postmark';
    }

    buildStatusClass(status) {
        const key = (status || 'sent').trim().toLowerCase().replace(/\s+/g, '-');
        return `conv-status conv-status-${key}`;
    }

    buildInitials(name) {
        const parts = (name || '').split(/\s+/).filter(Boolean);
        if (!parts.length) {
            return '?';
        }
        if (parts.length === 1) {
            return parts[0].substring(0, 2).toUpperCase();
        }
        return `${parts[0][0]}${parts[parts.length - 1][0]}`.toUpperCase();
    }

    buildTimeLabel(row) {
        const clock = (row.sentAtLabel || '').trim();
        const relative = (row.relativeLabel || '').trim();
        if (clock && relative) {
            return `${clock} (${relative})`;
        }
        return clock || relative || '';
    }

    get overlayClass() {
        return this.isOpen ? 'conv-overlay show' : 'conv-overlay';
    }

    get displayMessages() {
        return (this._messages || []).map((msg) => {
            const isExpanded = this.expandAllActive
                ? true
                : this.collapsedAllActive
                    ? false
                    : this.expandedId === msg.key;
            return {
                ...msg,
                isExpanded,
                rowClass: isExpanded ? 'conv-msg expanded' : 'conv-msg collapsed',
                chevronClass: isExpanded ? 'conv-chevron open' : 'conv-chevron'
            };
        });
    }

    get hasMessages() {
        return this.displayMessages.length > 0;
    }

    get messageCountLabel() {
        const n = this._messages.length;
        return n === 1 ? '1 message' : `${n} messages`;
    }

    get threadStatsLabel() {
        const inbound = this.threadMeta.inboundCount || 0;
        const outbound = this.threadMeta.outboundCount || 0;
        return `${outbound} sent · ${inbound} received`;
    }

    get rootFromName() {
        return (this.threadMeta.rootFromParty?.name || '').trim();
    }

    get rootFromEmail() {
        return (this.threadMeta.rootFromParty?.email || '').trim();
    }

    get hasRootFrom() {
        return !!(this.rootFromName || this.rootFromEmail);
    }

    get rootToParties() {
        return (this.threadMeta.rootToParties || []).map((party, index) => ({
            key: `to-${index}`,
            name: (party.name || '').trim(),
            email: (party.email || '').trim(),
            showName: !!(party.name || '').trim(),
            showEmail: !!(party.email || '').trim()
        }));
    }

    get hasRootTo() {
        return this.rootToParties.length > 0;
    }

    get hasRootMeta() {
        return !!this.threadMeta.threadRootId;
    }

    get rootStatusClass() {
        return this.buildStatusClass(this.threadMeta.rootStatus);
    }

    get collapseAllLabel() {
        return this.collapsedAllActive && !this.expandAllActive ? 'Expand all' : 'Collapse all';
    }

    get showCopyFeedback() {
        return !!this.copyFeedback;
    }

    renderedCallback() {
        if (!this.isOpen || this.isLoading) {
            return;
        }
        const bodyById = new Map((this._messages || []).map((m) => [m.key, m.bodyHtml]));
        this.template.querySelectorAll('[data-body-host]').forEach((host) => {
            const id = host.dataset.id;
            const html = bodyById.get(id);
            const safeHtml = html && html.trim() ? html : '<p class="conv-empty">No message content.</p>';
            if (host._renderedHtml === safeHtml) {
                return;
            }
            host.innerHTML = safeHtml;
            host._renderedHtml = safeHtml;
        });
        if (this._pendingScrollToLatest) {
            this._pendingScrollToLatest = false;
            this.scrollToLatest(false);
        }
    }

    scrollToLatest(smooth = true) {
        if (!this._messages.length) {
            return;
        }
        const lastKey = this._messages[this._messages.length - 1].key;
        const behavior = smooth ? 'smooth' : 'auto';

        const scrollToTarget = () => {
            const node = this.template.querySelector(`[data-scroll-id="${lastKey}"]`);
            if (node) {
                node.scrollIntoView({ behavior, block: 'end' });
                return;
            }
            const scroller = this.template.querySelector('.conv-scroll');
            if (scroller) {
                scroller.scrollTo({ top: scroller.scrollHeight, behavior });
            }
        };

        // eslint-disable-next-line @lwc/lwc/no-async-operation
        requestAnimationFrame(() => {
            scrollToTarget();
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            requestAnimationFrame(scrollToTarget);
        });
        // Allow expanded body HTML to affect layout before final scroll.
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(scrollToTarget, smooth ? 150 : 0);
    }

    handleBackdropClick(event) {
        if (event.target === event.currentTarget) {
            this.handleClose();
        }
    }

    stopProp(event) {
        event.stopPropagation();
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleToggleCollapseAll() {
        if (this.collapsedAllActive && !this.expandAllActive) {
            this.handleExpandAll();
            return;
        }
        this.expandAllActive = false;
        this.collapsedAllActive = true;
        this.expandedId = null;
    }

    handleExpandAll() {
        this.expandAllActive = true;
        this.collapsedAllActive = false;
        this.expandedId = null;
    }


    handleExpandLatest() {
        if (!this._messages.length) {
            return;
        }
        const last = this._messages[this._messages.length - 1];
        this.expandAllActive = false;
        this.collapsedAllActive = false;
        this.expandedId = last.key;
        this._pendingScrollToLatest = true;
    }

    handleJumpToLatest(event) {
        event?.stopPropagation();
        this.handleExpandLatest();
    }

    handleToggleMessage(event) {
        const id = event.currentTarget.dataset.id;
        this.expandAllActive = false;
        this.collapsedAllActive = false;
        this.expandedId = this.expandedId === id ? null : id;
    }

    handleOpenAttachment(event) {
        event.stopPropagation();
        const contentDocumentId = event.currentTarget.dataset.docId;
        const attachmentRecordId = event.currentTarget.dataset.attId;
        const storageKind = event.currentTarget.dataset.kind;

        if (contentDocumentId || storageKind === 'ContentDocument') {
            this[NavigationMixin.Navigate]({
                type: 'standard__namedPage',
                attributes: {
                    pageName: 'filePreview'
                },
                state: {
                    recordIds: contentDocumentId,
                    selectedRecordId: contentDocumentId
                }
            });
            return;
        }

        if (attachmentRecordId) {
            window.open(`/servlet/servlet.FileDownload?file=${attachmentRecordId}`, '_blank', 'noopener');
        }
    }

    async handleCopy(event) {
        event.stopPropagation();
        const value = event.currentTarget.dataset.copy;
        if (!value) {
            return;
        }
        try {
            await navigator.clipboard.writeText(value);
            this.copyFeedback = 'Copied to clipboard';
        } catch (e) {
            this.copyFeedback = 'Copy failed';
        }
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            this.copyFeedback = '';
        }, 1800);
    }

    handleReply() {
        this.dispatchEvent(
            new CustomEvent('reply', {
                detail: { threadRootId: this.threadMeta.threadRootId }
            })
        );
    }

    handleReplyAll() {
        this.dispatchEvent(
            new CustomEvent('replyAll', {
                detail: { threadRootId: this.threadMeta.threadRootId }
            })
        );
    }
}
