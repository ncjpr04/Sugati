import { LightningElement, api } from 'lwc';

const STAGES = [
    { id: 'all', label: 'All stages' },
    { id: 'enquiry', label: 'Enquiry' },
    { id: 'proposal', label: 'Proposal' },
    { id: 'booked', label: 'Booked' },
    { id: 'pre-dep', label: 'Pre-Departure ●', active: true },
    { id: 'travelling', label: 'Travelling' },
    { id: 'post', label: 'Post-Trip' }
];

const TEMPLATES = [
    {
        id: '1',
        name: 'Pre-trip Welcome Pack',
        meta: 'Traveller · B2C · Pre-Departure',
        preview:
            'Dear Traveller First Name, We are delighted to share your final itinerary for Destination Country…',
        suggested: true,
        usage: 'Used 3× at this stage',
        stage: 'pre-dep'
    },
    {
        id: '2',
        name: 'Final Itinerary & Documents',
        meta: 'Traveller · B2C · Pre-Departure',
        preview:
            'Dear Traveller First Name, your complete travel documents for Destination Country are now attached…',
        suggested: true,
        usage: 'Used 2× at this stage',
        stage: 'pre-dep'
    },
    {
        id: '3',
        name: 'Balance Due Reminder',
        meta: 'Traveller · B2C · Booked',
        preview:
            'Dear Traveller First Name, a friendly reminder that your balance of Balance Due is due on Payment Due Date…',
        suggested: false,
        usage: 'Booked stage',
        stage: 'booked'
    },
    {
        id: '4',
        name: 'Supplier Booking Request',
        meta: 'Supplier · Ops · Booked',
        preview:
            'Dear Supplier Contact First Name, please confirm availability and rate for Trip Start Date…',
        suggested: false,
        usage: 'Booked stage',
        stage: 'booked'
    },
    {
        id: '5',
        name: 'Post-Trip Feedback Request',
        meta: 'Traveller · B2C · Post-Trip',
        preview:
            'Dear Traveller First Name, we hope you had a wonderful journey to Destination Country…',
        suggested: false,
        usage: 'Post-Trip stage',
        stage: 'post'
    }
];

export default class SugatiCommunicationTemplatePicker extends LightningElement {
    @api tripName = 'Tokyo Honeymoon 2026';
    @api stageLabel = 'Pre-Departure';

    selectedStage = 'all';
    _escapeHandler;

    connectedCallback() {
        this._escapeHandler = (event) => {
            if (event.key === 'Escape') {
                this.handleClose();
            }
        };
        window.addEventListener('keydown', this._escapeHandler);
        document.body.style.overflow = 'hidden';
    }

    disconnectedCallback() {
        if (this._escapeHandler) {
            window.removeEventListener('keydown', this._escapeHandler);
        }
        document.body.style.overflow = '';
    }

    get stageFilters() {
        return STAGES.map((s) => {
            let cls = 'tmpl-sf';
            if (s.id === this.selectedStage) {
                cls += ' on';
            }
            if (s.active) {
                cls += ' active-stage';
            }
            return { ...s, className: cls };
        });
    }

    get visibleTemplates() {
        return TEMPLATES.filter((t) => {
            if (this.selectedStage === 'all') {
                return true;
            }
            return t.stage === this.selectedStage;
        }).map((t) => ({
            ...t,
            itemClass: t.suggested ? 'tmpl-pick-item suggested' : 'tmpl-pick-item'
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

    handleStageClick(event) {
        this.selectedStage = event.currentTarget.dataset.stage;
    }

    handleSelect(event) {
        const { name, meta, stage } = event.currentTarget.dataset;
        this.dispatchEvent(
            new CustomEvent('select', {
                detail: { name: name || '', meta: meta || '', stage: stage || '' }
            })
        );
        this.handleClose();
    }

    handleBlank() {
        this.dispatchEvent(new CustomEvent('select', { detail: { name: '', meta: '', stage: '' } }));
        this.handleClose();
    }

    stopPropagation(event) {
        event.stopPropagation();
    }
}
