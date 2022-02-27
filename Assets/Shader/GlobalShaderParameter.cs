using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEditor.ShaderGraph;
using System.Reflection;


[ExecuteInEditMode]
public class GlobalShaderParameter : MonoBehaviour
{

    [Range(0.0f, 1.0f)]
    public float NightEnvironmentIntensity = 0.2f;

    [Range(0.0f, 5.0f)]
    public float DayEnvironmentIntensity = 1.2f;

    [Range(0.0f, 2.0f)]
    public float LightSwitch = 0.0f; //场景的光照控制,0代表白天，1代表夜晚



    public float NightLightIntensity = 0.05f;
    public float DayLightIntensity = 1;
    public float NightReflection = 0.5f;

    [Range(0.0f, 1.0f)]
    public float NightShadowIntensity;
    public Light MainCityLight;

    public Vector3 DayPosition;
    public Vector3 NightPosition;

    public float Loop;
    public Light[] lights;

    public float Daytemperature = 10.0f;
    public float Nighttemperature = -15.0f;

    public Material mat;

    public float temperature;

    public Color DayGIColor; //230 250 253
    public Color NightGIColor; //50 53 75
    public Color GIColor;

    void Start()
    {
        GameObject L = this.gameObject;
        //lights = L.GetComponentsInChildren<Light>();

        foreach(var i in lights)
        {
            i.gameObject.SetActive(false);
        }


    }

    void Update()
    {

        LightSwitch += 0.0001f;
        
        Loop = Mathf.Min(LightSwitch, 1.0f) * (1 - Mathf.Clamp(LightSwitch - 1.0f, 0.0f, 1.0f));

        float DayEnvironmentControl = Mathf.Lerp(DayEnvironmentIntensity, 0.0f, Loop);

        temperature = Mathf.Lerp(Daytemperature, Nighttemperature, Loop);
        Vector3 TintColor = UnityEngine.Rendering.Color​Utils.ColorBalanceToLMSCoeffs(temperature, 0.0f);

        mat.SetVector("_TemperatureColor", TintColor);

        Shader.SetGlobalFloat("_GITest", Loop + 0.0001f);
        Shader.SetGlobalFloat("_NightIntensity", NightEnvironmentIntensity);
        Shader.SetGlobalFloat("_DayIntensity", DayEnvironmentControl);
        Shader.SetGlobalFloat("_ReflectionIntensity", NightReflection);

        GIColor = Color.Lerp(DayGIColor, NightGIColor, Loop);
        Shader.SetGlobalColor("_GIColor", GIColor);

        Light[] MainLight = Light.GetLights(LightType.Directional, 0);

        float LightIntensity = Mathf.Lerp(DayLightIntensity, NightLightIntensity, Loop);
        MainCityLight.intensity = LightIntensity;
        MainCityLight.shadowStrength = Mathf.Lerp(1.0f, NightShadowIntensity, Loop);

        if(LightSwitch >= 1.0001f && LightSwitch <= 1.0002f)
        {   
            DayPosition.x -= 360f;
        }
        if(LightSwitch >= 2.0f){LightSwitch = 0.0f; NightPosition.x -= 360f;}

        MainCityLight.transform.localEulerAngles = Vector3.Lerp(DayPosition, NightPosition, Loop);

        if(Loop >= 0.5f)
        {
            foreach(var i in lights)
            {
                i.gameObject.SetActive(true);
                i.intensity = Mathf.Lerp(0.0f, 5.0f, Mathf.Clamp(Loop - 0.5f, 0.0f, 0.2f) * 5.0f);
                i.range = Mathf.Lerp(0.0f, 100.0f, Mathf.Clamp(Loop - 0.5f, 0.0f, 0.2f) * 5.0f);
            }
        }

        if(Loop < 0.5f)
        {   
            foreach(var i in lights)
            {
            i.gameObject.SetActive(false);
            }
        }

        

    }



    //光照移动
    // private void moveSunInpectorEulers()
    // {
    //     //早上6点到中午12点 x轴 0-90度  y 0-180
    //     //中午12点到下午6点 x轴 90-0度  y 180-360
    //     float cycleTime = 6;//6小时一个轮回
    //     float time = cycleTime*60*60;
    //     float hour = System.DateTime.Now.Hour;
    //     float minute = System.DateTime.Now.Minute;
    //     float second = System.DateTime.Now.Second;
    //     float timwNow = 0;//现在的时间（秒）
    //     float angle = 90; //顶点角度
    //     float _x = 0;
    //     float _y = 0;
        
    //     if(hour >= 6 && hour <12)
    //     {
    //         timwNow = (hour -cycleTime)*3600+minute*60+second;
    //         _x = angle/time* timwNow;
    //     }
    //     else if(hour>=12 && hour <18)
    //     {
    //         timwNow = (hour -cycleTime*2)*3600+minute*60+second;
    //         _x = angle-(angle/time* timwNow);
    //     }
    //     else if(hour>=18 && hour <=24)
    //     {
    //         timwNow = (hour -cycleTime*3)*3600+minute*60+second;
    //         _x = angle/time* timwNow;
    //     }
    //     else if(hour>=0 && hour <6)
    //     {
    //          timwNow = hour*3600+minute*60+second;
    //          _x = angle-(angle/time* timwNow);
    //     }
    //     if(hour <cycleTime)
    //     {
    //         hour = hour-6+24;
    //     }
    //     else
    //     {
    //         hour = hour -cycleTime;
    //     }
    //     timwNow = hour*3600+minute*60+second;
    //     _y = 360/(time*4)*timwNow;
    //     // Debug.Log(" timwNow:  " + timwNow+"  hour = "+hour+"  minute = "+minute);
    //     transform.localEulerAngles= new Vector3(_x,_y,0);
    // }

}
