import { LightningElement, api } from 'lwc';

const MODES = [
    { id: 'compose', label: 'Compose' },
    { id: 'rewrite', label: 'Rewrite' },
    { id: 'subject', label: 'Subject' },
    { id: 'attachments', label: 'Attachments' }
];

const TONES = ['Warm & personal', 'Formal', 'Concise'];

export default class SugatiCommunicationAiAssist extends LightningElement {
    @api isOpen = false;
    @api tripName = 'Tokyo Honeymoon 2026';
    @api recipientSummary = 'Hiroshi & Akemi Yamamura';
    @api templateName = 'Pre-trip Welcome Pack';
    @api departureDate = '12 Apr 2026';

    activeMode = 'compose';
    selectedTone = 'Warm & personal';
    isLoading = false;
    showOutput = false;
    outputLabel = 'Generated draft';
    outputBody = '';
    subjectResults = [];
    attachmentResults = [];

    get overlayClass() {
        return this.isOpen ? 'ai-assist-overlay open' : 'ai-assist-overlay';
    }

    get modeTabs() {
        return MODES.map((m) => ({
            ...m,
            className: m.id === this.activeMode ? 'ai-mode-tab on' : 'ai-mode-tab'
        }));
    }

    get showCompose() {
        return this.activeMode === 'compose';
    }

    get showRewrite() {
        return this.activeMode === 'rewrite';
    }

    get showSubject() {
        return this.activeMode === 'subject';
    }

    get showAttachments() {
        return this.activeMode === 'attachments';
    }

    get toneOptions() {
        return TONES.map((t) => ({
            label: t,
            className: t === this.selectedTone ? 'ai-tone-opt on' : 'ai-tone-opt'
        }));
    }

    handleBackdropClick(event) {
        if (event.target === event.currentTarget) {
            this.handleClose();
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleModeClick(event) {
        this.activeMode = event.currentTarget.dataset.mode;
        this.showOutput = false;
        this.isLoading = false;
    }

    handleToneClick(event) {
        this.selectedTone = event.currentTarget.dataset.tone;
    }

    simulateAi(callback) {
        this.isLoading = true;
        this.showOutput = false;
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        setTimeout(() => {
            callback();
            this.isLoading = false;
            this.showOutput = true;
        }, 1400);
    }

    handleCompose() {
        this.simulateAi(() => {
            this.outputLabel = 'Generated draft';
            this.outputBody =
                'Dear {{Traveller First Name}},\n\nWe are delighted to share your final itinerary for {{Destination Country}}. Your trip begins on {{Trip Start Date}} — just {{Days Until Departure}} days away.\n\nPlease find your documents attached.\n\nWarm regards,\n{{Specialist Name}}';
        });
    }

    handleRewrite(event) {
        const mode = event.currentTarget.dataset.rewrite;
        this.simulateAi(() => {
            this.outputLabel = `Rewritten (${mode})`;
            if (mode === 'simplify') {
                this.outputBody = 'Dear Hiroshi & Akemi,\n\nYour Tokyo itinerary and entry documents are attached. Your trip starts 12 April 2026.\n\nSarah Mitchell · Sugati Travel';
            } else if (mode === 'expand') {
                this.outputBody =
                    'Dear Hiroshi & Akemi,\n\nIt is our absolute pleasure to share your beautifully crafted final itinerary for your honeymoon in Japan. Every detail has been personally reviewed by our team.\n\nWarmest regards,\nSarah Mitchell';
            } else {
                this.outputBody =
                    'Dear Mr & Mrs Yamamura,\n\nPlease find enclosed your final travel documentation for departure on 12 April 2026.\n\nYours sincerely,\nSarah Mitchell · Sugati Travel';
            }
        });
    }

    handleSubject() {
        this.simulateAi(() => {
            this.subjectResults = [
                'Your Tokyo Honeymoon — Final Itinerary & Arrival Details',
                'Japan awaits — your documents are ready',
                '12 April departure — everything you need for Tokyo'
            ];
            this.showOutput = false;
        });
    }

    handleAttachments() {
        this.simulateAi(() => {
            this.attachmentResults = [
                'Tokyo Itinerary Final.pdf',
                'Japan Entry Requirements.pdf',
                'Hotel Vouchers Pack.pdf'
            ];
            this.showOutput = false;
        });
    }

    handleApply() {
        this.dispatchEvent(
            new CustomEvent('apply', {
                detail: {
                    mode: this.activeMode,
                    body: this.outputBody,
                    subjects: this.subjectResults,
                    attachments: this.attachmentResults
                }
            })
        );
        this.handleClose();
    }

    handleRegenerate() {
        if (this.activeMode === 'compose') {
            this.handleCompose();
        }
    }
}
