import { LightningElement, api } from 'lwc';

/**
 * The circumference of the SVG score ring circle.
 * Calculated as 2 * π * r where r = 32 (the SVG circle radius).
 * Used to compute stroke-dashoffset for the animated ring fill.
 */
const SVG_CIRCLE_CIRCUMFERENCE = 201;

/**
 * Minimum score floor applied when a metric has a non-zero value
 * but would otherwise round down to zero. Ensures the ring is
 * always visibly filled when there is some data.
 */
const MINIMUM_REVENUE_SCORE  = 15;
const MINIMUM_ACTIVITY_SCORE = 20;

/**
 * Partner Health Score component for the Agency page.
 * Displays three animated ring charts showing Overall, Revenue
 * and Activity scores derived from the Supplier record's
 * total commission value and total bed nights fields.
 */
export default class SugatiAgencyPartnerHealth extends LightningElement {

    /** Supplier sObject passed from the parent SugatiAgencyTab component */
    @api supplier;

    /** Supplier Booking records — reserved for future score calculations */
    @api supplierBookings = [];

    // ---- PUBLIC GETTERS ----

    /**
     * Computes all three health scores from the Supplier record.
     * Revenue score is based on total commission value (max at £100,000).
     * Activity score is based on total bed nights (max at 100 nights).
     * Overall score is the average of revenue and activity scores.
     * A minimum floor score is applied when a metric is non-zero but
     * rounds down to zero, to ensure the ring is always visibly filled.
     * @returns {object} Object with revenueScore, activityScore and overallScore (0–100)
     */
    get scores() {
        const totalCommissionValue = this.supplier?.sugati__S_Total_Commission_Value__c || 0;
        const totalBedNights       = this.supplier?.sugati__S_Total_Bed_Nights__c       || 0;

        let revenueScore  = Math.min(Math.floor((totalCommissionValue / 100000) * 100), 100);
        let activityScore = Math.min(Math.floor((totalBedNights / 100) * 100), 100);

        // Apply minimum floor scores to avoid invisible rings when data exists
        if (revenueScore === 0 && totalCommissionValue > 0) {
            revenueScore = MINIMUM_REVENUE_SCORE;
        }
        if (activityScore === 0 && totalBedNights > 0) {
            activityScore = MINIMUM_ACTIVITY_SCORE;
        }

        // Reset both to zero if neither metric has any data
        if (totalCommissionValue === 0 && totalBedNights === 0) {
            revenueScore  = 0;
            activityScore = 0;
        }

        const overallScore = Math.floor((revenueScore + activityScore) / 2);

        return { revenueScore, activityScore, overallScore };
    }

    /**
     * Returns the overall health score (0–100).
     * @returns {number}
     */
    get overallScore() {
        return this.scores.overallScore;
    }

    /**
     * Returns the revenue health score (0–100).
     * @returns {number}
     */
    get revenueScore() {
        return this.scores.revenueScore;
    }

    /**
     * Returns the activity health score (0–100).
     * @returns {number}
     */
    get activityScore() {
        return this.scores.activityScore;
    }

    /**
     * Returns the SVG stroke-dashoffset style for the overall score ring.
     * A score of 100 fills the ring completely; 0 leaves it empty.
     * @returns {string} Inline style string for stroke-dashoffset
     */
    get overallRingStyle() {
        return this.buildRingStyle(this.scores.overallScore);
    }

    /**
     * Returns the SVG stroke-dashoffset style for the revenue score ring.
     * @returns {string} Inline style string for stroke-dashoffset
     */
    get revenueRingStyle() {
        return this.buildRingStyle(this.scores.revenueScore);
    }

    /**
     * Returns the SVG stroke-dashoffset style for the activity score ring.
     * @returns {string} Inline style string for stroke-dashoffset
     */
    get activityRingStyle() {
        return this.buildRingStyle(this.scores.activityScore);
    }

    // ---- PRIVATE METHODS ----

    /**
     * Builds the stroke-dashoffset inline style string for a given score.
     * Uses SVG_CIRCLE_CIRCUMFERENCE to calculate the visible arc length.
     * @param {number} score - The score value between 0 and 100
     * @returns {string} Inline style string e.g. 'stroke-dashoffset: 100.5'
     */
    buildRingStyle(score) {
        const offset = SVG_CIRCLE_CIRCUMFERENCE - (score / 100) * SVG_CIRCLE_CIRCUMFERENCE;
        return `stroke-dashoffset: ${offset}`;
    }
}