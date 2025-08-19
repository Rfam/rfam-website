/**
 * Type definitions for Nightingale component events
 */
export interface NightingaleChangeDetail {
    displaystart?: number;
    displayend?: number;
    'display-start'?: number;
    'display-end'?: number;
    length?: number;
    source?: string;
}
export interface NightingaleChangeEvent extends Event {
    detail: NightingaleChangeDetail;
}
export type NightingaleEventListener = (event: Event) => void;
export declare function asCustomEvent(event: Event): CustomEvent;
export declare function getEventDetail(event: Event): NightingaleChangeDetail | null;
export declare function getDisplayStart(detail: NightingaleChangeDetail): number | undefined;
export declare function getDisplayEnd(detail: NightingaleChangeDetail): number | undefined;
export declare function createNightingaleChangeEvent(type: string, detail: NightingaleChangeDetail): CustomEvent;
