import { BasePair } from '../../types';
export declare class LinksDataProcessor {
    /**
     * Generate base pair links from secondary structure consensus
     */
    static generateBasePairLinks(consensus: string, addBuffer?: boolean): BasePair[];
    /**
     * Format base pairs for nightingale-links component in TSV format
     */
    static formatForNightingaleTSV(basePairs: BasePair[]): string;
    /**
     * Add buffer base pair to existing array if not present
     */
    static addBufferIfNeeded(basePairs: BasePair[]): BasePair[];
    /**
     * Format base pairs for nightingale-links component based on the source code
     */
    static formatForNightingale(basePairs: BasePair[]): any[];
    /**
     * Convert from API features format to base pairs
     */
    static convertFeaturesBasePairs(features: any[]): BasePair[];
}
