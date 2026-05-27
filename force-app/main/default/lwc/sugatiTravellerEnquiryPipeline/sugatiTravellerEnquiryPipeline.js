import { LightningElement, api, wire } from 'lwc';
import getOpportunityTasks from '@salesforce/apex/SugatiTravellerPageCtrl.getOpportunityTasks';

/**
 * Maps partial stage name substrings to display colours and sort order.
 * Substring matching is used intentionally so client-configured stage names
 * that contain these keywords are still coloured correctly.
 * Note: for exact stage name comparisons elsewhere, use OpportunityStageMapper.
 */
const STAGE_COLOR_MAP = [
    { match: 'booked',        color: '#2e9e6b', order: 1 },
    { match: 'confirmed',     color: '#2e9e6b', order: 1 },
    { match: 'quoting',       color: '#3a7fc1', order: 2 },
    { match: 'proposal',      color: '#c8930a', order: 3 },
    { match: 'enquiry',       color: '#e07820', order: 4 },
    { match: 'qualification', color: '#9a9a94', order: 5 },
    { match: 'prospecting',   color: '#d04040', order: 6 }
];

/** Fallback meta used when no entry in STAGE_COLOR_MAP matches the stage name. */
const DEFAULT_STAGE_META = { color: '#9a9a94', order: 99 };

/** Milliseconds in one day — used for follow-up date difference calculations. */
const MS_PER_DAY = 1000 * 60 * 60 * 24;

/**
 * Returns the colour and sort order metadata for a given stage name
 * by performing a case-insensitive substring match against STAGE_COLOR_MAP.
 * @param  {String|null} stageName - The raw StageName value.
 * @return {{ color: String, order: Number }} Metadata object.
 */
function getStageMeta(stageName) {
    const normalisedStage = (stageName || '').toLowerCase();
    return STAGE_COLOR_MAP.find(entry => normalisedStage.includes(entry.match)) || DEFAULT_STAGE_META;
}

export default class SugatiTravellerEnquiryPipeline extends LightningElement {

    /**
     * List of Opportunity records to display in the pipeline bar.
     * Expected fields: StageName.
     */
    @api opportunities;

    /**
     * Salesforce record Id of the Account, used to wire opportunity tasks.
     */
    @api accountId;

    /** @type {Array} Internal store for wired opportunity Task records. */
    opportunityTasks = [];

    // ── Wire handlers ─────────────────────────────────────────────────────

    /**
     * Wires Task records linked to the account's opportunities.
     * Populates opportunityTasks when data is returned, clears it on error.
     * @param {Object} data  - The returned list of Task records.
     * @param {Object} error - Any error returned by the wire service.
     */
    @wire(getOpportunityTasks, { accountId: '$accountId' })
    wiredTasks({ data, error }) {
        if (data) {
            this.opportunityTasks = data;
        } else if (error) {
            this.opportunityTasks = [];
        }
    }

    // ── Computed properties — follow-up ───────────────────────────────────

    /**
     * Returns the most relevant Task for the next follow-up.
     * Prefers the soonest upcoming task; falls back to the most recent past task
     * when no future tasks exist. Returns null when no tasks are available.
     * @return {Object|null}
     */
    get nextFollowUp() {
        if (!this.opportunityTasks?.length) {
            return null;
        }
        const today = new Date();

        const upcomingTask = [...this.opportunityTasks]
            .filter(task => task.ActivityDate && new Date(task.ActivityDate) >= today)
            .sort((taskA, taskB) => new Date(taskA.ActivityDate) - new Date(taskB.ActivityDate))[0];

        if (upcomingTask) {
            return upcomingTask;
        }
        return [...this.opportunityTasks]
            .filter(task => task.ActivityDate && new Date(task.ActivityDate) < today)
            .sort((taskA, taskB) => new Date(taskB.ActivityDate) - new Date(taskA.ActivityDate))[0]
            || null;
    }

    /**
     * Returns a human-readable string describing the next follow-up task,
     * including how far away it is and its subject.
     * Returns 'No follow-ups scheduled' when no tasks exist.
     * @return {String}
     */
    get nextFollowUpText() {
        if (!this.nextFollowUp) {
            return 'No follow-ups scheduled';
        }
        const taskDate  = new Date(this.nextFollowUp.ActivityDate);
        const today     = new Date();
        const diffDays  = Math.floor((taskDate - today) / MS_PER_DAY);

        let timeLabel;
        if (diffDays === 0)       { timeLabel = 'Today'; }
        else if (diffDays === 1)  { timeLabel = 'Tomorrow'; }
        else if (diffDays < 0)    { timeLabel = `${Math.abs(diffDays)} days ago`; }
        else                      { timeLabel = `in ${diffDays} days`; }

        return `${timeLabel} · ${this.nextFollowUp.Subject}`;
    }

    // ── Computed properties — pipeline bar ────────────────────────────────

    /**
     * Returns a map of StageName → count across all provided opportunities.
     * @return {Object} Plain object keyed by stage name with integer counts.
     */
    get stageCounts() {
        const countsByStage = {};
        (this.opportunities || []).forEach(opportunity => {
            const stageName = opportunity.StageName || 'Other';
            countsByStage[stageName] = (countsByStage[stageName] || 0) + 1;
        });
        return countsByStage;
    }

    /**
     * Converts stageCounts into an array of display-ready segment objects,
     * each containing bar and dot inline styles, a label and a tooltip.
     * Segments are sorted by their stage order ascending.
     * @return {Array} Sorted array of segment objects for template rendering.
     */
    get stageSegments() {
        const stageEntries = Object.entries(this.stageCounts);
        const total        = stageEntries.reduce((sum, [, count]) => sum + count, 0) || 1;

        return stageEntries
            .map(([stageName, count]) => {
                const stageMeta    = getStageMeta(stageName);
                const pct          = (count / total) * 100;
                const pctRounded   = Math.round(pct);
                const labelPrefix  = stageMeta.order === 1 ? '✓ ' : '';

                return {
                    stage      : stageName,
                    count,
                    order      : stageMeta.order,
                    label      : `${labelPrefix}${count} ${stageName}`,
                    tooltip    : `${stageName}: ${count} (${pctRounded}%)`,
                    pctRounded,
                    barStyle   : `flex:${count} 0 0px; min-width:60px; background:${stageMeta.color};`,
                    dotStyle   : `background:${stageMeta.color};`
                };
            })
            .sort((segmentA, segmentB) => segmentA.order - segmentB.order);
    }

    // ── Computed properties — empty state ─────────────────────────────────

    /**
     * Returns true when at least one opportunity is available for display.
     * @return {Boolean}
     */
    get hasOpportunities() {
        return (this.opportunities || []).length > 0;
    }
}