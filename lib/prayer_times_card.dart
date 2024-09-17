import 'package:flutter/material.dart';

class PrayerTimesCard extends StatefulWidget {
  final Map<String, String> prayerTimes;

  const PrayerTimesCard({super.key, required this.prayerTimes, required this.nextPrayer});

  final String nextPrayer;

  @override
  State<PrayerTimesCard> createState() => _PrayerTimesCardState();
}

class _PrayerTimesCardState extends State<PrayerTimesCard> {

  

  @override
  Widget build(BuildContext context) {
    
    
    return Card(
      elevation: 5,
      color: Colors.white.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            
            
            ...widget.prayerTimes.entries.map((entry) {
              return Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12),
                child: Container(
                  decoration: widget.nextPrayer != entry.key ? const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey,
                        width: 0.5,
                      ),
                    ),
                  ) : 
                  const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.black,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: widget.nextPrayer == entry.key
                                ? FontWeight.bold
                                : FontWeight.normal),
                      ),
                      Text(
                        entry.value,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: widget.nextPrayer == entry.key
                                ? FontWeight.bold
                                : FontWeight.normal),
                      ),
                      
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
