using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System.IO;

public class RecordPerformance : MonoBehaviour
{
    string filename = Application.dataPath + "/FRAMEDATA.txt";
    bool startCollect = false;
    private void Update()
    {
        if(Input.GetKeyDown(KeyCode.Space))
        {
            startCollect = true;
        }
        if (startCollect)
        {
            SaveFrameData();
        }
        if(Input.GetKeyDown(KeyCode.Escape))
        {
            Application.Quit();
        }
    }

    void SaveFrameData()
    {
        TextWriter gw = new StreamWriter(filename, true);
        gw.WriteLine(Time.deltaTime * 1000 + "\n");
        gw.Close();
    }


}
