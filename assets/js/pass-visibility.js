// A geometric flyover is only observable while the ISS is sunlit and the observer is dark.
// Keep separate illuminated segments so a shadow crossing never counts as visible time.
export function qualifyPass(pass, sunAltitude) {
  const segments = [];
  let segment = [];
  const flush = () => {
    if (segment.length >= 2) {
      const first = segment[0], last = segment[segment.length - 1];
      const peak = segment.reduce((a, b) => b.elevation > a.elevation ? b : a);
      if (peak.elevation >= 20 && last.timestamp - first.timestamp >= 60) {
        segments.push({ ...pass, start: first.timestamp, end: last.timestamp,
          duration: Math.round((last.timestamp - first.timestamp) / 60), maxEl: peak.elevation,
          peakPoint: peak, points: segment, night: true, visible: true });
      }
    }
    segment = [];
  };
  for (const point of pass.points) {
    // Refined samples are ten seconds apart. Missing propagation data must not bridge a gap.
    if (segment.length && point.timestamp - segment[segment.length - 1].timestamp > 20) flush();
    if (point.elevation > 0 && point.sunlit === true && sunAltitude(point.timestamp) < -6) segment.push(point);
    else flush();
  }
  flush();
  return segments.length ? segments : [{ ...pass, visible: false,
    night: sunAltitude(pass.peakPoint.timestamp) < -6 }];
}
