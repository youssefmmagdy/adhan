import 'package:flutter/material.dart';

class PrayerTimesCard extends StatefulWidget {
  final Map<String, String> prayerTimes;

  const PrayerTimesCard({super.key, required this.prayerTimes});

  @override
  State<PrayerTimesCard> createState() => _PrayerTimesCardState();
}

class _PrayerTimesCardState extends State<PrayerTimesCard> {
  String? nextPrayer;

  @override
  void initState() {
    super.initState();
    getNextPrayer();
  }

  void getNextPrayer() {
    final now = DateTime.now();
    now.add(const Duration(hours: 3));
    int min = 9999999;

    widget.prayerTimes.entries.map((entry) {
      final time = entry.value.split(':');
      final hours = int.parse(time[0]);
      final minutes = int.parse(time[1]);
      
      if (min > ((hours - now.hour) * 60 + (minutes - now.minute)) &&
          ((hours - now.hour) > 0 ||((hours == now.hour) && (minutes - now.minute) >= 0))) {
        
        setState(() {
          min = (hours - now.hour) * 60 + (minutes - now.minute);
          nextPrayer = entry.key;
        });

      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    
    
    if(nextPrayer == null){
      nextPrayer = "Fajr";
    }
    
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
                  decoration: nextPrayer != entry.key ? const BoxDecoration(
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
                            fontWeight: nextPrayer == entry.key
                                ? FontWeight.bold
                                : FontWeight.normal),
                      ),
                      Text(
                        entry.value,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: nextPrayer == entry.key
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
