import { LightningElement, api } from 'lwc';
import getSendEmailTemplateCatalog from '@salesforce/apex/SugatiCommunicationHubController.getSendEmailTemplateCatalog';

const ALL_STAGES = '__all__';

export default class SugatiCommunicationTemplatePicker extends LightningElement {
    @api tripName = '';
    @api stageLabel = '';
    @api opportunityId;

    selectedTemplateId = null;
    _escapeHandler;
    _catalog = {
        templates: [],
        relatedRecords: [],
        opportunityStage: null,
        templateStageForOpportunity: null,
        currentUserId: null,
        opportunityStageOrder: []
    };
    selectedStageFilter = ALL_STAGES;
    isLoading = true;
    loadError = null;

    connectedCallback() {
        this._escapeHandler = (event) => {
            if (event.key === 'Escape') {
                this.handleClose();
            }
        };
        window.addEventListener('keydown', this._escapeHandler);
        document.body.style.overflow = 'hidden';
        this.loadCatalog();
    }

    disconnectedCallback() {
        if (this._escapeHandler) {
            window.removeEventListener('keydown', this._escapeHandler);
        }
        document.body.style.overflow = '';
    }

    get stageDisplay() {
        return this._catalog.opportunityStage || this.stageLabel || 'Current';
    }

    get tripDisplay() {
        return this.tripName || 'Opportunity';
    }

    get effectiveTemplateStage() {
        return (
            this._catalog.templateStageForOpportunity ||
            this._catalog.opportunityStage ||
            this.stageLabel ||
            ''
        );
    }

    get showStageFilters() {
        return !this.isLoading && !this.loadError && this.orderedTemplateStages.length > 0;
    }

    get orderedTemplateStages() {
        return (this._catalog.opportunityStageOrder || [])
            .map((stage) => (stage || '').trim())
            .filter((stage) => stage.length > 0);
    }

    get stageFilters() {
        const oppStage = this.effectiveTemplateStage;
        const filters = [
            {
                id: ALL_STAGES,
                label: 'All stages',
                isSelected: this.selectedStageFilter === ALL_STAGES,
                className: this.stageFilterClass(ALL_STAGES, false)
            }
        ];
        this.orderedTemplateStages.forEach((stage) => {
            const isOppStage =
                !!oppStage && this.normalizeStageKey(oppStage) === this.normalizeStageKey(stage);
            filters.push({
                id: stage,
                label: isOppStage ? `${stage} ●` : stage,
                isSelected: this.isStageFilterSelected(stage),
                className: this.stageFilterClass(stage, isOppStage)
            });
        });
        return filters;
    }

    isStageFilterSelected(stage) {
        if (this.selectedStageFilter === ALL_STAGES) {
            return false;
        }
        return this.normalizeStageKey(this.selectedStageFilter) === this.normalizeStageKey(stage);
    }

    stageFilterClass(stageId, isOppStage) {
        let cls = 'tmpl-sf';
        if (stageId === ALL_STAGES) {
            if (this.selectedStageFilter === ALL_STAGES) {
                cls += ' on';
            }
            return cls;
        }
        if (this.isStageFilterSelected(stageId)) {
            cls += ' on';
        } else if (isOppStage) {
            cls += ' active-stage';
        }
        return cls;
    }

    get filteredTemplates() {
        const filterKey =
            this.selectedStageFilter === ALL_STAGES
                ? null
                : this.normalizeStageKey(this.selectedStageFilter);
        const filtered = (this._catalog.templates || []).filter((t) => {
            if (!filterKey) {
                return true;
            }
            if (!t.templateStage) {
                return false;
            }
            return this.normalizeStageKey(t.templateStage) === filterKey;
        });
        return this.sortTemplatesByOpportunityStage(filtered);
    }

    get visibleTemplates() {
        const oppStage = this.effectiveTemplateStage;
        return this.filteredTemplates.map((t) => {
            const isSuggested = this.isTemplateSuggested(t, oppStage);
            const name = t.name || 'Template';
            return {
                ...t,
                isSuggested,
                pickClass: this.buildPickClass(isSuggested, t.id),
                pickMeta: this.buildPickMeta(t),
                pickPreview: this.buildPickPreview(t),
                pickUse: this.buildPickUse(t, isSuggested),
                ariaLabel: `Use template ${name}`
            };
        });
    }

    buildPickClass(isSuggested, id) {
        let cls = 'tmpl-pick-item';
        if (isSuggested) {
            cls += ' suggested';
        }
        if (this.selectedTemplateId === id) {
            cls += ' selected';
        }
        return cls;
    }

    buildPickMeta(t) {
        const parts = [];
        if (t.templateName) {
            parts.push(t.templateName);
        }
        parts.push('Opportunity');
        if (t.templateStage) {
            parts.push(t.templateStage);
        } else if (t.assignedUserName) {
            parts.push(t.assignedUserName);
        }
        return parts.join(' · ');
    }

    buildPickPreview(t) {
        const raw = (t.intro || t.closing || '').trim();
        if (!raw) {
            return 'Template will pre-fill subject and body for this opportunity.';
        }
        const plain = raw.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
        return plain.length > 120 ? `${plain.substring(0, 117)}…` : plain;
    }

    buildPickUse(t, isSuggested) {
        if (isSuggested) {
            return 'Suggested for this stage';
        }
        if (t.templateStage) {
            return `${t.templateStage} stage`;
        }
        return 'Opportunity template';
    }

    get hasNoTemplates() {
        return !this.isLoading && !this.loadError && this.visibleTemplates.length === 0;
    }

    handleBackdropClick(event) {
        if (event.target === event.currentTarget) {
            this.handleClose();
        }
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleStageFilter(event) {
        this.selectedStageFilter = event.currentTarget.dataset.stage || ALL_STAGES;
    }

    handleTemplatePick(event) {
        const id = event.currentTarget.dataset.id;
        this.selectTemplateById(id);
    }

    handleTemplateKeydown(event) {
        if (event.key !== 'Enter' && event.key !== ' ') {
            return;
        }
        event.preventDefault();
        const id = event.currentTarget.dataset.id;
        this.selectTemplateById(id);
    }

    selectTemplateById(id) {
        const selected = (this._catalog.templates || []).find((t) => t.id === id);
        if (!selected) {
            return;
        }
        this.selectedTemplateId = id;
        this.confirmSelection(selected);
    }

    handleBlank() {
        this.dispatchEvent(new CustomEvent('select', { detail: { blank: true } }));
        this.handleClose();
    }

    confirmSelection(selected) {
        const relatedId = this.opportunityId;
        this.dispatchEvent(
            new CustomEvent('select', {
                detail: {
                    configId: selected.id,
                    templateName: selected.templateName || selected.name,
                    name: selected.name,
                    relatedRecordId: relatedId,
                    relatedObjectType: 'Opportunity',
                    meta: selected.meta
                }
            })
        );
        this.handleClose();
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    syncDefaultStageFilter() {
        this.selectedStageFilter = ALL_STAGES;
    }

    normalizeStageKey(stage) {
        return (stage || '').trim().toLowerCase();
    }

    getStageOrderIndex(stage) {
        const key = this.normalizeStageKey(stage);
        if (!key) {
            return 9999;
        }
        const order = this._catalog.opportunityStageOrder || [];
        const index = order.findIndex((s) => this.normalizeStageKey(s) === key);
        return index >= 0 ? index : 9998;
    }

    sortStagesByOpportunityOrder(stages) {
        return [...stages].sort((a, b) => this.getStageOrderIndex(a) - this.getStageOrderIndex(b));
    }

    isTemplateSuggested(t, oppStage) {
        if (!oppStage || !t.templateStage) {
            return false;
        }
        return this.normalizeStageKey(t.templateStage) === this.normalizeStageKey(oppStage);
    }

    sortTemplatesByOpportunityStage(templates) {
        const oppStage = this.effectiveTemplateStage;
        return [...templates].sort((a, b) => {
            const aSuggested = this.isTemplateSuggested(a, oppStage);
            const bSuggested = this.isTemplateSuggested(b, oppStage);
            if (aSuggested !== bSuggested) {
                return aSuggested ? -1 : 1;
            }
            const stageDiff = this.getStageOrderIndex(a.templateStage) - this.getStageOrderIndex(b.templateStage);
            if (stageDiff !== 0) {
                return stageDiff;
            }
            return (a.name || '').localeCompare(b.name || '', undefined, { sensitivity: 'base' });
        });
    }

    async loadCatalog() {
        this.isLoading = true;
        this.loadError = null;
        if (!this.opportunityId) {
            this._catalog = {
                templates: [],
                relatedRecords: [],
                opportunityStage: null,
                templateStageForOpportunity: null,
                currentUserId: null,
                opportunityStageOrder: []
            };
            this.isLoading = false;
            return;
        }
        try {
            this._catalog = await getSendEmailTemplateCatalog({ opportunityId: this.opportunityId });
            if (!this._catalog) {
                this._catalog = {
                    templates: [],
                    relatedRecords: [],
                    opportunityStage: null,
                    templateStageForOpportunity: null,
                    currentUserId: null,
                    opportunityStageOrder: []
                };
            }
            if (!this._catalog.opportunityStageOrder) {
                this._catalog.opportunityStageOrder = [];
            }
            this.syncDefaultStageFilter();
        } catch (e) {
            this.loadError = e?.body?.message || e?.message || 'Unable to load templates.';
            this._catalog = {
                templates: [],
                relatedRecords: [],
                opportunityStage: null,
                templateStageForOpportunity: null,
                currentUserId: null,
                opportunityStageOrder: []
            };
            this.selectedStageFilter = ALL_STAGES;
        } finally {
            this.isLoading = false;
        }
    }
}
