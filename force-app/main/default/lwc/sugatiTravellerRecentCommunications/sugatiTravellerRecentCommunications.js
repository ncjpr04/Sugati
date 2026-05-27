import { LightningElement, api } from 'lwc';

/** Number of communication items shown before the expand toggle is activated. */
const PREVIEW_COUNT = 3;

/** Milliseconds in one day — used for relative date calculations. */
const MS_PER_DAY = 86400000;

/** Placeholder displayed when a date value is not available. */
const EMPTY_VALUE = '—';

export default class SugatiTravellerRecentCommunications extends LightningElement {

    /**
     * List of Task records to display in the communications list.
     * Expected fields: ActivityDate, TaskSubtype, Type, Subject, Id.
     */
    @api tasks;

    /** Controls whether all items or only the first PREVIEW_COUNT are shown. */
    _expanded = false;

    // ── Private helpers ───────────────────────────────────────────────────

    /**
     * Derives the display icon, CSS class and label for a given task type string
     * by performing case-insensitive substring matching.
     * @param  {String|null} typeRaw - The raw TaskSubtype or Type value.
     * @return {{ icon: String, class: String, label: String }} Type metadata object.
     */
    getTypeInfo(typeRaw) {
        const normalisedType = (typeRaw || '').toLowerCase();

        if (normalisedType.includes('call') || normalisedType.includes('phone')) {
            return { icon: '📞', class: 'comm-phone', label: 'Call' };
        }
        if (normalisedType.includes('email')) {
            return { icon: '✉', class: 'comm-email', label: 'Email' };
        }
        if (normalisedType.includes('task') || normalisedType.includes('note')) {
            return { icon: '📝', class: 'comm-note', label: 'Task' };
        }
        if (normalisedType.includes('linkedin')) {
            return { icon: '🔗', class: 'comm-linkedin', label: 'LinkedIn' };
        }
        if (normalisedType.includes('cadence') || normalisedType.includes('sequence')) {
            return { icon: '🔁', class: 'comm-cadence', label: 'Cadence' };
        }
        return { icon: '✉', class: 'comm-email', label: 'Email' };
    }

    /**
     * Returns a human-readable relative date string for a given date value,
     * e.g. 'Today', 'Yesterday', '3 days ago', 'Jan 2025'.
     * Returns '—' when no date is supplied.
     * @param  {String|null} dateValue - ISO date string to evaluate.
     * @return {String} Relative date string.
     */
    relDate(dateValue) {
        if (!dateValue) {
            return EMPTY_VALUE;
        }
        const daysDiff = Math.floor((Date.now() - new Date(dateValue)) / MS_PER_DAY);

        if (daysDiff === 0) { return 'Today'; }
        if (daysDiff === 1) { return 'Yesterday'; }
        if (daysDiff < 7)   { return `${daysDiff} days ago`; }
        if (daysDiff < 14)  { return '1 week ago'; }
        if (daysDiff < 30)  { return `${Math.floor(daysDiff / 7)} weeks ago`; }

        return new Date(dateValue).toLocaleDateString('en-GB', {
            month : 'short',
            year  : 'numeric'
        });
    }

    // ── Computed properties ───────────────────────────────────────────────

    /**
     * Filters tasks to those with a past or today's activity date and maps each
     * to a display-ready object with icon, CSS class, type label and relative date.
     * Results are sorted with the most recent activity first.
     * @return {Array} Array of enriched Task display objects.
     */
    get pastTasks() {
        const today = new Date();

        return (this.tasks || [])
            .filter(task => task.ActivityDate && new Date(task.ActivityDate) <= today)
            .map(task => {
                const typeInfo = this.getTypeInfo(task.TaskSubtype || task.Type || '');
                return {
                    ...task,
                    icon      : typeInfo.icon,
                    iconClass : `comm-icon ${typeInfo.class}`,
                    typeLabel : typeInfo.label,
                    dateLabel : this.relDate(task.ActivityDate)
                };
            });
    }

    /**
     * Returns the subset of past tasks visible in the list,
     * respecting the expanded toggle.
     * @return {Array}
     */
    get visibleTasks() {
        return this._expanded
            ? this.pastTasks
            : this.pastTasks.slice(0, PREVIEW_COUNT);
    }

    /**
     * Returns true when the total number of past tasks exceeds the preview limit.
     * @return {Boolean}
     */
    get hasMore() {
        return this.pastTasks.length > PREVIEW_COUNT;
    }

    /**
     * Returns the total number of past task activities.
     * @return {Number}
     */
    get taskCount() {
        return this.pastTasks.length;
    }

    /**
     * Returns the label for the expand/collapse toggle link.
     * @return {String}
     */
    get toggleLabel() {
        return this._expanded ? 'View less ↑' : `View all ${this.taskCount} →`;
    }

    /**
     * Returns the CSS class string for the list wrapper, adding the
     * 'expanded' modifier when all items are shown.
     * @return {String}
     */
    get listWrapClass() {
        return this._expanded ? 'list-wrap expanded' : 'list-wrap';
    }

    // ── Event handlers ────────────────────────────────────────────────────

    /**
     * Toggles the expanded flag to show or hide the full communications list.
     * Resets scroll position to the top when collapsing.
     */
    toggle() {
        this._expanded = !this._expanded;

        // Reset scroll to top when collapsing so the list returns to the start.
        requestAnimationFrame(() => {
            const listWrapEl = this.template.querySelector('.list-wrap');
            if (listWrapEl && !this._expanded) {
                listWrapEl.scrollTop = 0;
            }
        });
    }
}