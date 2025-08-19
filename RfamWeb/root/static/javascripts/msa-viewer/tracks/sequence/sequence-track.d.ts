import { BaseTrack, TrackConfig, TrackData } from '../base/base-track';
interface SequenceTrackConfig extends TrackConfig {
    label: string;
    dataSource: 'notation' | 'consensus';
    sequenceName?: string;
}
export declare class SequenceTrack extends BaseTrack {
    private label;
    private dataSource;
    private sequenceName;
    constructor(config: SequenceTrackConfig, data: TrackData);
    createHTML(): string;
    setup(container: HTMLElement): void;
    update(config?: Partial<SequenceTrackConfig>, data?: Partial<TrackData>): void;
    destroy(): void;
    private getSequenceData;
    private setupSequenceElement;
}
export {};
