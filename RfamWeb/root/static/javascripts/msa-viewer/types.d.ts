export interface MSASequence {
    name: string;
    sequence: string;
}
export interface MSAData {
    sequences: MSASequence[];
    reference?: string;
}
export interface BasePair {
    x: number;
    y: number;
    a: number;
    b: number;
    score: number;
}
export interface SecondaryStructure {
    consensus: string;
    basePairs?: BasePair[];
}
