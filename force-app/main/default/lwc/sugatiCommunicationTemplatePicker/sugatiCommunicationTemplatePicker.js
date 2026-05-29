import { LightningElement, api } from 'lwc';
import getTemplates from '@salesforce/apex/SugatiCommunicationHubController.getTemplates';

export default class SugatiCommunicationTemplatePicker extends LightningElement {
    @api tripName = '';
    @api stageLabel = '';
    @api opportunityId;

    selectedStage = 'all';
    _escapeHandler;
    _templates = [];

    connectedCallback() {
        this._escapeHandler = (event) => {
            if (event.key === 'Escape') {
                this.handleClose();
            }
        };
        window.addEventListener('keydown', this._escapeHandler);
        document.body.style.overflow = 'hidden';
        this.loadTemplates();
    }

    disconnectedCallback() {
        if (this._escapeHandler) {
            window.removeEventListener('keydown', this._escapeHandler);
        }
        document.body.style.overflow = '';
    }

    get stageFilters() {
        const dynamic = Array.from(new Set(this._templates.map((t) => t.stage).filter(Boolean))).map((stage) => ({
            id: stage.toLowerCase(),
            label: stage,
            active: stage === this.stageLabel
        }));
        return [{ id: 'all', label: 'All stages' }, ...dynamic].map((s) => {
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
        return this._templates.filter((t) => {
            if (this.selectedStage === 'all') {
                return true;
            }
            return (t.stage || '').toLowerCase() === this.selectedStage;
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

    async loadTemplates() {
        if (!this.opportunityId) {
            return;
        }
        try {
            const rows = await getTemplates({
                opportunityId: this.opportunityId,
                stage: null,
                recipientType: null,
                channel: 'Email'
            });
            this._templates = (rows || []).map((row, idx) => ({
                id: row.id,
                name: row.name,
                meta: row.meta,
                stage: row.stage,
                preview: (row.body || '').replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim(),
                suggested: idx < 2,
                usage: row.stage ? `${row.stage} stage` : 'Template'
            }));
        } catch (e) {
            this._templates = [];
        }
    }
}
