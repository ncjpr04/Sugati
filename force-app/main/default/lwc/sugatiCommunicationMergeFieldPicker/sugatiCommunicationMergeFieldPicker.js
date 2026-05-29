import { LightningElement, api, wire } from 'lwc';
import getMergeTokens from '@salesforce/apex/SugatiCommunicationHubController.getMergeTokens';

export default class SugatiCommunicationMergeFieldPicker extends LightningElement {
    @api embedded = false;
    @api opportunityId;

    selectedObjectId = 'opportunity';
    tokenGroups = [];
    fieldMap = {};

    @wire(getMergeTokens, { opportunityId: '$opportunityId' })
    wiredTokens({ data }) {
        if (!data) {
            return;
        }
        this.tokenGroups = data.groups || [];
        this.fieldMap = data.fieldsByGroup || {};
        if (this.tokenGroups.length && !this.tokenGroups.find((g) => g.id === this.selectedObjectId)) {
            this.selectedObjectId = this.tokenGroups[0].id;
        }
    }

    get objectGroups() {
        return this.tokenGroups.map((obj) => ({
            ...obj,
            rowClass: obj.id === this.selectedObjectId ? 'mfp-obj on' : 'mfp-obj',
            sidebarClass: obj.id === this.selectedObjectId ? 'sb-item on' : 'sb-item'
        }));
    }

    get fields() {
        return (this.fieldMap[this.selectedObjectId] || []).map((f) => ({
            ...f,
            rowClass: f.highlight ? 'mfp-f hi' : 'mfp-f',
            tokenLabel: f.api
        }));
    }

    get panelClass() {
        return this.embedded ? 'mfp-wrap embedded' : 'mfp-wrap fullpage';
    }

    handleObjectClick(event) {
        this.selectedObjectId = event.currentTarget.dataset.id;
    }

    handleFieldClick(event) {
        const label = event.currentTarget.dataset.label;
        this.dispatchEvent(
            new CustomEvent('tokeninsert', {
                detail: { label, token: `{{${label}}}` },
                bubbles: true,
                composed: true
            })
        );
    }

    handleBack() {
        this.dispatchEvent(new CustomEvent('back', { bubbles: true, composed: true }));
    }
}
