import { LightningElement, api } from 'lwc';

const DEFAULT_ITEMS = [
    {
        id: 'tl-1',
        channel: 'email',
        subject: 'Pre-trip Welcome & Itinerary Pack',
        who: 'Hiroshi & Akemi Yamamura',
        pillClass: 'pill p-go',
        pillLabel: 'Opened × 3',
        when: '2 Mar 2026, 09:41',
        dotColor: 'var(--go)',
        tagClass: 'tag tag-email',
        tagLabel: '✉ Email',
        isDraft: false,
        statusLabel: '● Opened × 3',
        statusClass: 'tl-dm-status opened',
        statusStyle: '',
        sentAt: '09:41 · 2 Mar 2026',
        sentBy: 'Sarah Mitchell',
        recipientLabel: 'Recipients',
        recipients: 'Hiroshi Yamamura\nAkemi Yamamura',
        delivery: 'Postmark (tracked)',
        attachmentsLabel: '2 files',
        extraLabel: 'First opened',
        extraValue: '2 Mar 2026, 11:02',
        emailHeading: 'Welcome to Your Tokyo Adventure',
        emailBody: 'Dear Hiroshi & Akemi, we are so excited to welcome you on this journey. Please find your initial itinerary and Japan entry requirements attached.',
        emailCta: 'View Itinerary Online',
        hasAttachments: true,
        attachmentChips: [
            { name: 'Tokyo Itinerary v1.pdf', type: 'PDF', iconClass: 'tl-att-ic pdf' },
            { name: 'Japan Entry Requirements.pdf', type: 'GEN', iconClass: 'tl-att-ic gen' }
        ]
    },
    {
        id: 'tl-2',
        channel: 'wa',
        subject: 'Arrival reminder — Park Hyatt Tokyo check-in',
        who: 'Hiroshi Yamamura',
        pillClass: 'pill p-wa',
        pillLabel: 'Read',
        when: '1 Mar 2026, 14:10',
        dotColor: 'var(--ch-wa)',
        tagClass: 'tag tag-wa',
        tagLabel: '💬 WhatsApp',
        isDraft: false,
        statusLabel: '● Read',
        statusClass: 'tl-dm-status',
        statusStyle: 'color:var(--ch-wa)',
        sentAt: '14:10 · 1 Mar 2026',
        sentBy: 'Sarah Mitchell',
        recipientLabel: 'Recipient',
        recipients: 'Hiroshi Yamamura',
        delivery: 'WhatsApp Cloud API',
        template: 'arrival_reminder_v2',
        extraLabel: 'Read at',
        extraValue: '14:23 · 1 Mar 2026',
        waLines: [
            'Hello Hiroshi 👋',
            'A quick reminder — your Park Hyatt Tokyo check-in is tomorrow, 12 April at 3:00pm.',
            'Your transfer from Narita is booked and confirmed. Driver: Yamamoto-san.',
            'Any questions, Sarah is here. Safe travels! ✈️'
        ]
    },
    {
        id: 'tl-3',
        channel: 'ia',
        subject: 'Your itinerary documents are ready to view',
        who: 'Hiroshi & Akemi Yamamura',
        pillClass: 'pill p-ia',
        pillLabel: 'Delivered',
        when: '28 Feb 2026, 11:30',
        dotColor: 'var(--ch-ia)',
        tagClass: 'tag tag-ia',
        tagLabel: '🔔 In-App',
        isDraft: false,
        statusLabel: '● Delivered',
        statusClass: 'tl-dm-status',
        statusStyle: 'color:var(--ch-ia)',
        sentAt: '11:30 · 28 Feb 2026',
        sentBy: 'Sarah Mitchell',
        recipientLabel: 'Recipients',
        recipients: 'Hiroshi Yamamura\nAkemi Yamamura',
        delivery: 'Experience Cloud',
        typeLabel: 'Document notification',
        iaIcon: '📄',
        iaTitle: 'Documents Ready',
        iaMsg: 'Your final Tokyo itinerary, hotel vouchers, and Japan entry requirements are now available in your trip documents. Tap to view and download.',
        iaCta: 'View Documents →'
    },
    {
        id: 'tl-4',
        channel: 'email',
        subject: 'Park Hyatt Tokyo — Booking Confirmation Request',
        who: 'reservations@parkhyatt.co.jp',
        pillClass: 'pill p-info',
        pillLabel: 'Delivered',
        when: '28 Feb 2026, 09:22',
        dotColor: 'var(--info)',
        tagClass: 'tag tag-email',
        tagLabel: '✉ Email',
        isDraft: false,
        statusLabel: '● Delivered',
        statusClass: 'tl-dm-status delivered',
        statusStyle: '',
        sentAt: '09:22 · 28 Feb 2026',
        sentBy: 'Sarah Mitchell',
        recipientLabel: 'Recipient',
        recipients: 'reservations@parkhyatt.co.jp',
        delivery: 'Postmark (tracked)',
        emailHeading: 'Booking Confirmation Request',
        emailBody: 'Dear Park Hyatt Reservations team, please confirm availability for a Deluxe Room for 2 guests from 12 April to 19 April 2026. Guest names: Hiroshi & Akemi Yamamura. Reference: TOK-2026-0412.',
        emailCta: 'Confirm Booking',
        hasAttachments: false,
        attachmentsLabel: 'None'
    },
    {
        id: 'tl-5',
        channel: 'wa',
        subject: 'Flight check-in reminder — 24 hours',
        who: 'Hiroshi Yamamura',
        pillClass: 'pill p-wa',
        pillLabel: 'Read',
        when: '25 Feb 2026, 08:00',
        dotColor: 'var(--ch-wa)',
        tagClass: 'tag tag-wa',
        tagLabel: '💬 WhatsApp',
        isDraft: false,
        statusLabel: '● Read',
        statusClass: 'tl-dm-status',
        statusStyle: 'color:var(--ch-wa)',
        sentAt: '08:00 · 25 Feb 2026',
        sentBy: 'Sarah Mitchell',
        recipientLabel: 'Recipient',
        recipients: 'Hiroshi Yamamura',
        delivery: 'WhatsApp Cloud API',
        template: 'flight_checkin_reminder',
        extraLabel: 'Read at',
        extraValue: '08:14 · 25 Feb 2026',
        waLines: [
            'Good morning Hiroshi! 🌅',
            'Your flight to Tokyo departs in 24 hours. Check-in opens now.',
            'Flight: JL 402 · Departing 10:45 · Terminal 3, Heathrow.',
            'Have a wonderful journey! Sarah & the Sugati team.'
        ]
    },
    {
        id: 'tl-6',
        channel: 'email',
        subject: 'Japan Visa & Entry Requirements — Draft',
        who: 'Hiroshi Yamamura',
        pillClass: 'pill p-grey',
        pillLabel: 'Draft',
        when: 'Last edited 1 Mar 2026',
        dotColor: 'var(--t4)',
        tagClass: 'tag tag-email',
        tagLabel: '✉ Email',
        isDraft: true,
        statusLabel: '● Draft',
        statusClass: 'tl-dm-status draft',
        statusStyle: '',
        sentBy: 'Sarah Mitchell',
        recipientLabel: 'Recipient',
        recipients: 'Hiroshi Yamamura',
        lastEdited: '1 Mar 2026',
        emailHeading: 'Japan Entry Requirements',
        emailBody: 'Dear Hiroshi, please find attached the latest Japan entry requirements for your trip in April 2026. British citizens do not require a visa for stays under 90 days.',
        hasAttachments: false
    }
];

export default class SugatiCommunicationHistory extends LightningElement {
    @api displayMode = 'hub';
    @api tripTitle = 'Tokyo Honeymoon 2026';
    @api tripSubtitle = 'Yamamura';

    channelFilter = null;
    expandedId = null;
    activeSidebar = 'all';
    _items = DEFAULT_ITEMS.map((i) => ({ ...i }));

    emailCount = 6;
    waCount = 3;
    iaCount = 2;

    get isHubMode() {
        return this.displayMode === 'hub';
    }

    get isHistoryOnly() {
        return this.displayMode === 'history';
    }

    get rootClass() {
        return this.isHubMode ? 'hub' : 'history-layout';
    }

    get hubTitle() {
        return this.isHistoryOnly ? 'Communication History' : 'All Communications';
    }

    get timelineItems() {
        return this._items
            .filter((item) => !this.channelFilter || item.channel === this.channelFilter)
            .map((item) => ({
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

    _buildRowClass(item) {
        let cls = 'tl-item';
        if (this.expandedId === item.id) cls += ' expanded';
        if (item.isNew) cls += ' new-entry';
        return cls;
    }

    handleRowClick(event) {
        // Only toggle if clicking the row itself, not the View button
        if (event.target.classList.contains('tl-act')) return;
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
        this.activeSidebar = key;
        this.template.querySelectorAll('.sb-item').forEach((el) => el.classList.remove('on'));
        event.currentTarget.classList.add('on');
    }

    handleChannelPill(event) {
        event.stopPropagation();
        const ch = event.currentTarget.dataset.channel;
        if (this.channelFilter === ch) {
            this.channelFilter = null;
            event.currentTarget.classList.remove('on');
        } else {
            this.channelFilter = ch;
            this.template.querySelectorAll('.sb-ch-pill').forEach((p) => p.classList.remove('on'));
            event.currentTarget.classList.add('on');
        }
    }

    handleContinueDraft(event) {
        event.stopPropagation();
        this.dispatchEvent(new CustomEvent('continuedraft'));
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
            who: entry.who || 'Hiroshi & Akemi Yamamura',
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
            sentBy: 'Sarah Mitchell',
            recipientLabel: 'Recipients',
            recipients: entry.recipients || 'Hiroshi Yamamura\nAkemi Yamamura',
            delivery: 'Postmark (tracked)',
            attachmentsLabel: entry.attachments || '3 files',
            emailHeading: entry.subject || 'Your Tokyo Honeymoon — Final Itinerary',
            emailBody: 'Your complete itinerary has been sent successfully.',
            emailCta: 'View Online',
            hasAttachments: true,
            attachmentChips: [
                { name: 'Final Itinerary.pdf', type: 'PDF', iconClass: 'tl-att-ic pdf' }
            ],
            messageId: entry.messageId
        };
        this._items = [newItem, ...this._items];
        this.expandedId = newItem.id;
        this.emailCount += 1;
    }
}
