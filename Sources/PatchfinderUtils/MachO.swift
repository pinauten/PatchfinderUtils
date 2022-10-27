//
//  MachO.swift
//  PatchfinderUtils
//
//  Created by Linus Henze.
//  Copyright © 2022 Pinauten GmbH. All rights reserved.
//

import Foundation
import SwiftMachO
import CFastFind

public extension MachO {
    /// Return a PatchfinderSegment for a named segment, optionally sliding it.
    func pfSegment(forName name: String, slide: UInt64 = 0) -> PatchfinderSegment? {
        for lc in cmds {
            if let slc = lc as? Segment64LoadCommand {
                if slc.name == name {
                    guard slc.fileSize != 0 else {
                        return nil
                    }
                    
                    let segRange = Int(slc.fileOffset)..<Int(slc.fileOffset+slc.fileSize)
                    guard let dat = data.trySubdata(in: segRange) else {
                        return nil
                    }
                    
                    return PatchfinderSegment(data: dat, baseAddress: slc.vmAddr + slide, name: slc.name)
                }
            }
        }
        
        return nil
    }
    
    /// Return a PatchfinderSegment for a named section, optionally sliding it.
    func pfSection(segment seg: String, section: String, slide: UInt64 = 0) -> PatchfinderSegment? {
        for lc in cmds {
            if let slc = lc as? Segment64LoadCommand {
                if slc.name == seg {
                    guard slc.fileSize != 0 else {
                        return nil
                    }
                    
                    for sect in slc.sections {
                        if sect.section == section {
                            guard sect.size != 0 else {
                                return nil
                            }
                            
                            let sectStart = Int(sect.offset)
                            let sectEnd   = sectStart + Int(sect.size)
                            guard let dat = data.trySubdata(in: sectStart..<sectEnd) else {
                                return nil
                            }
                            
                            return PatchfinderSegment(data: dat, baseAddress: sect.address + slide, name: "\(seg),\(section)")
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Return PatchfinderSegments for all segments, optionally sliding them.
    func pfAllSegments(slide: UInt64 = 0) -> [PatchfinderSegment] {
        var res: [PatchfinderSegment] = []
        for lc in cmds {
            if let slc = lc as? Segment64LoadCommand {
                if slc.fileSize != 0 {
                    let segRange = Int(slc.fileOffset)..<Int(slc.fileOffset+slc.fileSize)
                    if let dat = data.trySubdata(in: segRange) {
                        let pfs = PatchfinderSegment(data: dat, baseAddress: slc.vmAddr + slide, name: slc.name)
                        res.append(pfs)
                    }
                }
            }
        }
        
        // Sort in ascending order by base address
        res.sort { $0.baseAddress < $1.baseAddress }
        
        return res
    }
    
    /**
     * Find a cross reference to some value, optionally starting at a given address and applying the given slide.
     *
     * - Parameter to: The value to cross-reference (must be slid if slide is set)
     * - Parameter startAt: Optional start address for the search (must be slid if slide is set)
     * - Parameter slide: Optional slide
     *
     * - Returns: Address (slid if slide is set) which references **to**, if any
     */
    func pfFindNextXref(to: UInt64, startAt: UInt64? = nil, slide: UInt64 = 0) -> UInt64? {
        var startAt = startAt
        
        for seg in pfAllSegments(slide: slide) {
            let s = startAt ?? seg.baseAddress
            let end = seg.baseAddress + UInt64(seg.data.count)
            if case seg.baseAddress..<end = s {
                if let res = seg.findNextXref(to: to, startAt: s) {
                    return res
                }
                
                // Nope, clear startAt since we now want to check all other segments
                // (only works because pfAllSegments sorts the segments)
                startAt = nil
            }
        }
        
        return nil
    }
}
