import { BasePair } from '../../types';
export declare class LinksDataProcessor {
    /**
     * Generate base pair links from secondary structure consensus
     */
    static generateBasePairLinks(consensus: string): BasePair[];
    /**
     * Format base pairs for nightingale-links component based on the source code
     */
    static formatForNightingale(basePairs: BasePair[]): any[];
}
