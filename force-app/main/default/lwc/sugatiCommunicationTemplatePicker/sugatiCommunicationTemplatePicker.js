import { LightningElement, api } from 'lwc';
import getSendEmailTemplateCatalog from '@salesforce/apex/SugatiCommunicationHubController.getSendEmailTemplateCatalog';

const ALL_STAGES = '__all__';

export default class SugatiCommunicationTemplatePicker extends LightningElement {
    @api tripName = '';
    @api stageLabel = '';
    @api opportunityId;

    selectedTemplateId = null;
    pendingTemplate = null;
    pendingRelatedRecordId = '';
    recordSearchTerm = '';
    templateSearchTerm = '';
    pickerStep = 'templates';
    _searchInputFocused = false;
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
            if (event.key !== 'Escape') {
                return;
            }
            if (this.isRecordStep) {
                this.handleCancelRelatedRecord();
            } else {
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

    get isRecordStep() {
        return this.pickerStep === 'record';
    }

    get pickerEyebrow() {
        return this.isRecordStep ? 'Step 2 of 2' : 'Step 1 of 2';
    }

    get headerTitle() {
        return this.isRecordStep ? 'Choose merge record' : 'Choose a template';
    }

    get pendingRelatedBadgeClass() {
        const raw = this.pendingTemplate?.relatedToRecord || 'Opportunity';
        return this.buildRelatedBadgeClass(raw);
    }

    get headerSubtitle() {
        if (this.isRecordStep) {
            return 'Pick which record supplies merge fields for this email';
        }
        const stage = this.stageDisplay;
        const trip = this.tripDisplay;
        return stage ? `${stage} · ${trip}` : trip;
    }

    get pendingTemplateName() {
        return this.pendingTemplate?.templateName || this.pendingTemplate?.name || 'Template';
    }

    get pendingRelatedTypeLabel() {
        return this.formatObjectLabel(this.pendingTemplate?.relatedToRecord || 'Record');
    }

    get stageDisplay() {
        const raw = this._catalog.opportunityStage || this.stageLabel || '';
        return this.stripStageSuffix(raw);
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

    get templateSearchQuery() {
        return (this.templateSearchTerm || '').trim().toLowerCase();
    }

    get showTemplateSearchClear() {
        return !!this.templateSearchQuery;
    }

    get filteredTemplates() {
        const q = this.templateSearchQuery;
        const filterKey =
            this.selectedStageFilter === ALL_STAGES
                ? null
                : this.normalizeStageKey(this.selectedStageFilter);
        const filtered = (this._catalog.templates || []).filter((t) => {
            if (filterKey) {
                if (!t.templateStage) {
                    return false;
                }
                if (this.normalizeStageKey(t.templateStage) !== filterKey) {
                    return false;
                }
            }
            if (!q) {
                return true;
            }
            const haystack = [
                t.name,
                t.templateName,
                t.meta,
                t.relatedToRecord,
                t.templateStage,
                t.assignedUserName,
                this.formatObjectLabel(t.relatedToRecord)
            ]
                .filter(Boolean)
                .join(' ')
                .toLowerCase();
            return haystack.includes(q);
        });
        return this.sortTemplatesByOpportunityStage(filtered);
    }

    get catalogTemplateCount() {
        return (this._catalog.templates || []).length;
    }

    get templateListSummary() {
        const shown = this.filteredTemplates.length;
        const total = this.catalogTemplateCount;
        if (this.isLoading) {
            return '';
        }
        if (this.loadError) {
            return '';
        }
        if (this.templateSearchQuery || this.selectedStageFilter !== ALL_STAGES) {
            return `${shown} of ${total} templates`;
        }
        return `${total} template${total === 1 ? '' : 's'}`;
    }

    get shouldGroupSuggested() {
        return (
            !this.templateSearchQuery &&
            this.selectedStageFilter === ALL_STAGES &&
            !this.isLoading &&
            !this.loadError
        );
    }

    get suggestedVisibleTemplates() {
        if (!this.shouldGroupSuggested) {
            return [];
        }
        return this.visibleTemplates.filter((t) => t.isSuggested);
    }

    get otherVisibleTemplates() {
        if (!this.shouldGroupSuggested) {
            return this.visibleTemplates;
        }
        return this.visibleTemplates.filter((t) => !t.isSuggested);
    }

    get showSuggestedSection() {
        return this.suggestedVisibleTemplates.length > 0;
    }

    get showOtherSectionLabel() {
        return this.shouldGroupSuggested && this.otherVisibleTemplates.length > 0;
    }

    get emptyStateTitle() {
        if (this.templateSearchQuery) {
            return 'No matching templates';
        }
        if (this.selectedStageFilter !== ALL_STAGES) {
            return 'No templates for this stage';
        }
        return 'No templates found';
    }

    get emptyStateMessage() {
        if (this.templateSearchQuery) {
            return 'Try a different search term or clear filters.';
        }
        if (this.selectedStageFilter !== ALL_STAGES) {
            return 'Choose another stage filter or start with a blank email.';
        }
        return 'Start with a blank email or check template setup for this trip.';
    }

    get recordListSummary() {
        const rows = this.filterRelatedRecords(this.pendingTemplate?.relatedToRecord || '');
        const shown = this.filteredRecordRows.length;
        if (!rows.length) {
            return '';
        }
        if (this.recordSearchTerm.trim()) {
            return `${shown} of ${rows.length} records`;
        }
        return `${rows.length} record${rows.length === 1 ? '' : 's'}`;
    }

    get visibleTemplates() {
        const oppStage = this.effectiveTemplateStage;
        return this.filteredTemplates.map((t) => {
            const isSuggested = this.isTemplateSuggested(t, oppStage);
            const displayName = t.templateName || t.name || 'Template';
            const relatedRaw = t.relatedToRecord || 'Opportunity';
            const stagePill = this.buildStagePillLabel(t);
            const pickPreview = this.buildPickPreview(t);
            return {
                ...t,
                displayName,
                isSuggested,
                pickClass: this.buildPickClass(isSuggested, t.id),
                pickPreview,
                showPickPreview: !!pickPreview,
                stagePill,
                showStagePill: !!stagePill,
                stagePillClass: this.buildStagePillClass(isSuggested),
                relatedBadge: this.formatObjectLabel(relatedRaw),
                relatedBadgeClass: this.buildRelatedBadgeClass(relatedRaw),
                showRelatedPill: true,
                ariaLabel: `Use template ${displayName}`
            };
        });
    }

    buildRelatedBadgeClass(relatedRaw) {
        const key = this.normalizeRelatedObjectKey(relatedRaw);
        return key === 'opportunity' ? 'tmpl-rel-badge opp' : 'tmpl-rel-badge custom';
    }

    formatObjectLabel(raw) {
        const key = this.normalizeRelatedObjectKey(raw);
        if (key === 'opportunity') {
            return 'Opportunity';
        }
        if (key === 'supplier_booking') {
            return 'Supplier booking';
        }
        if (key === 'supplier_cost_payment') {
            return 'Supplier cost / payment';
        }
        if (key === 'group_member') {
            return 'Traveller';
        }
        if (key === 'contact') {
            return 'Contact';
        }
        if (key === 'client_group') {
            return 'Client group';
        }
        return (raw || 'Record').replace(/__c$/i, '').replace(/_/g, ' ');
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

    buildStagePillLabel(t) {
        if (!t.templateStage) {
            return '';
        }
        return this.stripStageSuffix(t.templateStage);
    }

    buildStagePillClass(isSuggested) {
        let cls = 'tmpl-stage-pill';
        if (isSuggested) {
            cls += ' suggested';
        }
        return cls;
    }

    buildPickPreview(t) {
        const raw = (t.intro || t.closing || '').trim();
        if (!raw) {
            return '';
        }
        const plain = raw.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim();
        return plain.length > 120 ? `${plain.substring(0, 117)}…` : plain;
    }

    get hasNoTemplates() {
        return !this.isLoading && !this.loadError && this.filteredTemplates.length === 0;
    }

    get stepOneClass() {
        return this.isRecordStep ? 'tmpl-progress-step done' : 'tmpl-progress-step active';
    }

    get stepTwoClass() {
        if (this.isRecordStep) {
            return 'tmpl-progress-step active';
        }
        return 'tmpl-progress-step muted';
    }

    get showRelatedRecordPicker() {
        return !!this.pendingTemplate;
    }

    get confirmRelatedDisabled() {
        return !this.pendingRelatedRecordId;
    }

    get relatedRecordOptions() {
        const relatedType = this.pendingTemplate?.relatedToRecord || 'Opportunity';
        return this.filterRelatedRecords(relatedType).map((row) => ({
            label: row.label,
            value: row.recordId
        }));
    }

    get filteredRecordRows() {
        const term = (this.recordSearchTerm || '').trim().toLowerCase();
        const relatedType = this.pendingTemplate?.relatedToRecord || 'Opportunity';
        const rows = this.filterRelatedRecords(relatedType).map((row) => ({
            recordId: row.recordId,
            label: row.label,
            objectTypeLabel: this.formatObjectLabel(row.objectType),
            isSelected: row.recordId === this.pendingRelatedRecordId,
            rowClass:
                'tmpl-record-row' + (row.recordId === this.pendingRelatedRecordId ? ' selected' : '')
        }));
        if (!term) {
            return rows;
        }
        return rows.filter((row) => (row.label || '').toLowerCase().includes(term));
    }

    get hasRelatedRecordOptions() {
        return this.filterRelatedRecords(this.pendingTemplate?.relatedToRecord || '').length > 0;
    }

    get hasNoFilteredRecords() {
        return this.hasRelatedRecordOptions && this.filteredRecordRows.length === 0;
    }

    get relatedRecordEmptyMessage() {
        const type = this.formatObjectLabel(this.pendingTemplate?.relatedToRecord || 'record');
        return `No ${type} records exist on this Opportunity yet. Add one in the trip or pick a different template.`;
    }

    normalizeRelatedObjectKey(value) {
        let key = (value || '').trim().toLowerCase();
        if (key.startsWith('sugati__')) {
            key = key.substring('sugati__'.length);
        }
        return key.endsWith('__c') ? key.slice(0, -3) : key;
    }

    filterRelatedRecords(relatedObjectType) {
        const needle = this.normalizeRelatedObjectKey(relatedObjectType);
        return (this._catalog.relatedRecords || []).filter((row) => {
            return this.normalizeRelatedObjectKey(row.objectType) === needle;
        });
    }

    handleClose() {
        this.dispatchEvent(
            new CustomEvent('close', {
                detail: { navigateToChannel: true }
            })
        );
    }

    dismissPicker() {
        this.dispatchEvent(
            new CustomEvent('close', {
                detail: { navigateToChannel: false }
            })
        );
    }

    handleStageFilter(event) {
        this.selectedStageFilter = event.currentTarget.dataset.stage || ALL_STAGES;
    }

    handleTemplateSearch(event) {
        this.templateSearchTerm = event.target.value || '';
    }

    handleClearTemplateSearch() {
        this.templateSearchTerm = '';
        this.focusTemplateSearch();
    }

    focusTemplateSearch() {
        const input = this.template.querySelector('[data-id="template-search"]');
        if (input) {
            input.focus();
        }
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
        const relatedType = selected.relatedToRecord || 'Opportunity';

        if (this.normalizeRelatedObjectKey(relatedType) === 'opportunity') {
            this.confirmSelection(selected, this.opportunityId, relatedType);
            return;
        }

        const matches = this.filterRelatedRecords(relatedType);
        this.pendingTemplate = selected;
        this.recordSearchTerm = '';
        this.pickerStep = 'record';
        this.pendingRelatedRecordId = matches.length ? matches[0].recordId : '';
    }

    handleRecordSearchInput(event) {
        this.recordSearchTerm = event.target.value || '';
    }

    handleRecordRadioChange(event) {
        this.pendingRelatedRecordId = event.target.value;
    }

    handleConfirmRelatedRecord() {
        if (!this.pendingTemplate || !this.pendingRelatedRecordId) {
            return;
        }
        const match = (this._catalog.relatedRecords || []).find(
            (row) => row.recordId === this.pendingRelatedRecordId
        );
        this.confirmSelection(
            this.pendingTemplate,
            this.pendingRelatedRecordId,
            this.pendingTemplate.relatedToRecord || 'Opportunity',
            match?.label
        );
        this.resetRecordStep();
    }

    handleCancelRelatedRecord() {
        this.resetRecordStep();
    }

    resetRecordStep() {
        this.pendingTemplate = null;
        this.pendingRelatedRecordId = '';
        this.recordSearchTerm = '';
        this.pickerStep = 'templates';
    }

    renderedCallback() {
        if (
            !this._searchInputFocused &&
            !this.isRecordStep &&
            !this.isLoading &&
            !this.loadError &&
            this.catalogTemplateCount > 0
        ) {
            this._searchInputFocused = true;
            // eslint-disable-next-line @lwc/lwc/no-async-operation
            requestAnimationFrame(() => this.focusTemplateSearch());
        }
    }

    handleBlank() {
        this.dispatchEvent(new CustomEvent('select', { detail: { blank: true } }));
        this.dismissPicker();
    }

    confirmSelection(selected, relatedRecordId, relatedObjectType, relatedLabel) {
        const relatedId = relatedRecordId || this.opportunityId;
        this.dispatchEvent(
            new CustomEvent('select', {
                detail: {
                    configId: selected.id,
                    templateName: selected.templateName || selected.name,
                    name: selected.name,
                    relatedRecordId: relatedId,
                    relatedObjectType: relatedObjectType || 'Opportunity',
                    attachmentParentLabel: relatedLabel || this.tripDisplay,
                    meta: selected.meta
                }
            })
        );
        this.dismissPicker();
    }

    syncDefaultStageFilter() {
        const oppStage = this.effectiveTemplateStage;
        if (oppStage && this.orderedTemplateStages.some((s) => this.normalizeStageKey(s) === this.normalizeStageKey(oppStage))) {
            this.selectedStageFilter = this.orderedTemplateStages.find(
                (s) => this.normalizeStageKey(s) === this.normalizeStageKey(oppStage)
            );
            return;
        }
        this.selectedStageFilter = ALL_STAGES;
    }

    normalizeStageKey(stage) {
        return (stage || '').trim().toLowerCase();
    }

    stripStageSuffix(stage) {
        if (!stage) {
            return '';
        }
        return String(stage)
            .replace(/\s*stage\s*$/i, '')
            .trim();
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
            const aName = a.templateName || a.name || '';
            const bName = b.templateName || b.name || '';
            return aName.localeCompare(bName, undefined, { sensitivity: 'base' });
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
