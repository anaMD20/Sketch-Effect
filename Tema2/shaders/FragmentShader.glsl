#version 330

// Input
in vec2 texture_coord;

// Uniform properties
uniform sampler2D textureImage;
uniform ivec2 screenSize;
uniform int flipVertical;
uniform int outputMode = 2; // 0: original, 1: grayscale, 2: blur

// Output
layout(location = 0) out vec4 out_color;

// Local variables
vec2 textureCoord = vec2(texture_coord.x, (flipVertical != 0) ? 1 - texture_coord.y : texture_coord.y); // Flip texture


vec4 grayscale()
{
    vec4 color = texture(textureImage, textureCoord);
    float gray = 0.21 * color.r + 0.71 * color.g + 0.07 * color.b; 
    return vec4(gray, gray, gray,  0);
}


vec4 blur(int blurRadius)
{
    vec2 texelSize = 1.0f / screenSize;
    vec4 sum = vec4(0);
    for(int i = -blurRadius; i <= blurRadius; i++)
    {
        for(int j = -blurRadius; j <= blurRadius; j++)
        {
            sum += texture(textureImage, textureCoord + vec2(i, j) * texelSize);
        }
    }
        
    float samples = pow((2 * blurRadius + 1), 2);
    return sum / samples;
}

float sort_and_get_median(float a[25])
{
    int i, j;
    for(i = 0; i < 24; ++i)
	{
		for(j = 0; j < 24 - i; ++j)
		{
			if(a[j] > a[j+1])
			{
				float temp = a[j];
				a[j] = a[j+1];
				a[j+1] = temp;
			}
		}
	}
    return a[12];
}

vec4 median (int blurRadius)
{
	vec2 texelSize = 1.0f / screenSize;
	float arr_r[25], arr_g[25], arr_b[25];
	int k = 0;
	for(int i = -blurRadius; i <= blurRadius; i++)
	{
		for(int j = -blurRadius; j <= blurRadius; j++)
		{
			arr_r[k] = texture(textureImage, textureCoord + vec2(i, j) * texelSize).x;
            arr_g[k] = texture(textureImage, textureCoord + vec2(i, j) * texelSize).y;
            arr_b[k] = texture(textureImage, textureCoord + vec2(i, j) * texelSize).z;
            ++k;
		}
	}
	float color_r = sort_and_get_median(arr_r);
	float color_g = sort_and_get_median(arr_g);
	float color_b = sort_and_get_median(arr_b);
	out_color = vec4(color_r, color_g, color_b, 0);

    return out_color;
}

vec4 sobel()
{
    int blurRadius = 1;
    vec2 texelSize = 1.0f / screenSize;

    // Step 1: Apply blur
    vec4 blurredColor = vec4(0);
    for (int i = -blurRadius; i <= blurRadius; i++) {
        for (int j = -blurRadius; j <= blurRadius; j++) {
            blurredColor += texture(textureImage, textureCoord + vec2(i, j) * texelSize);
        }
    }
    float samples = pow((2 * blurRadius + 1), 2);
    blurredColor /= samples;

    float centerGray = 0.21 * blurredColor.r + 0.71 * blurredColor.g + 0.07 * blurredColor.b;

    float Gx[9] = float[](-1,  0,  1,
                          -2,  0,  2,
                          -1,  0,  1);

    float Gy[9] = float[](-1, -2, -1,
                           0,  0,  0,
                           1,  2,  1);

    float Dx = 0.0;
    float Dy = 0.0;
    int index = 0;

    // Apply Sobel on the blurred grayscale image
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            vec4 neighbor = vec4(0);
            for (int bi = -blurRadius; bi <= blurRadius; bi++) {
                for (int bj = -blurRadius; bj <= blurRadius; bj++) {
                    neighbor += texture(textureImage, textureCoord + vec2(i + bi, j + bj) * texelSize);
                }
            }
            neighbor /= samples;
            float neighborGray = 0.21 * neighbor.r + 0.71 * neighbor.g + 0.07 * neighbor.b;

            // Apply Sobel masks
            Dx += Gx[index] * neighborGray;
            Dy += Gy[index] * neighborGray;
            index++;
        }
    }

    // Magnitude of gradient
    float magnitude = sqrt(Dx * Dx + Dy * Dy);
    magnitude = clamp(magnitude, 0.0, 1.0);

    return vec4(vec3(magnitude), 1.0);
}




vec4 threshold(float thresholdValue)
{
	vec4 gradient = sobel();
	float intensity = gradient.r;

    if (intensity > thresholdValue)
    {
        return vec4(0, 0, 0, 0);
	}
	else
	{
        return vec4(1, 1, 1, 0);
	}
}

vec4 horizontalBlur(vec2 texCoord)
{
    vec2 texelSize = vec2( 1.0f / screenSize.x , 0.0f);
    vec4 sum = vec4(0);

    for (int i = -12; i <= 12; i++)
	{
		sum += texture(textureImage, texCoord + vec2(i, 0) * texelSize);
	}
    return sum / 25;
    
}

vec4 verticalBlur(vec2 texCoord)
{
	vec2 texelSize = vec2(0.0f, 1.0f / screenSize.y);
	vec4 sum = vec4(0);

	for (int i = -12; i <= 12; i++)
	{
		sum += horizontalBlur(texCoord + vec2(0, i) * texelSize);
	}
	return sum / 25;
}

vec4 hatch(float a, float b, float c, float threshold, vec4 color, bool inverted)
{
    float gray = 0.21 * color.r + 0.71 * color.g + 0.07 * color.b;
    if (gray < threshold) {
        float lineValue = sin(a * textureCoord.x + b * textureCoord.y);
        if (lineValue > c) {
            return inverted ? vec4(0, 0, 0, 1) : vec4(1, 1, 1, 1);
	    } else {
            return inverted ? vec4(1, 1, 1, 1) : vec4(0, 0, 0, 1);
	    }
    }
    return vec4(1, 1, 1, 1);
}

void main()
{
    vec4 sobelResult = sobel();
    switch (outputMode)
    {
        case 1:
        {
            out_color = threshold(0.15);
            break;
        }

        case 2:
        {
            out_color = horizontalBlur(textureCoord) ;
            break;
        }

        case 3:
		{
			out_color = verticalBlur(textureCoord);
			break;
		}

        case 4:
        {
	        vec4 smoothedColor = verticalBlur(textureCoord);
			out_color = hatch(300, 300, 0.95, 0.1, smoothedColor, false);
			break;
         }

        case 5:
        {
            vec4 smoothedColor = verticalBlur(textureCoord);
	        out_color = hatch(400, -400, 0.1, 0.3, smoothedColor, true);
            break;
        }

        case 6:
		{
            vec4 smoothedColor = verticalBlur(textureCoord);
			out_color = hatch(500, 500, 0.9, 0.5, smoothedColor, true);
			break;
		}

        case 7:
        {
			vec4 smoothedColor = verticalBlur(textureCoord);
            
            // primul hatch
            vec4 hatch1 = hatch(300, 300, 0.95, 0.1, smoothedColor, false);

            // al doilea hatch
			vec4 hatch2 = hatch(400, -400, 0.1, 0.3, smoothedColor, true);

			// al treilea hatch
			vec4 hatch3 = hatch(500, 500, 0.9, 0.5, smoothedColor, true);

			vec4 combinedHatch = min(hatch1, hatch2);
            combinedHatch = min(combinedHatch, hatch3);

            out_color = combinedHatch;
            break;

		}
        
        case 8:
        {
            vec4 thresholded = threshold(0.15);
            vec4 smoothedColor = verticalBlur(textureCoord);
        
            vec4 hatch1 = hatch(300, 300, 0.95, 0.1, smoothedColor, false);
            vec4 hatch2 = hatch(400, -400, 0.1, 0.3, smoothedColor, true);
            vec4 hatch3 = hatch(500, 500, 0.9, 0.5, smoothedColor, true);

            vec4 combinedHatch = min(hatch1, hatch2);
            combinedHatch = min(combinedHatch, hatch3);
            out_color = min(thresholded, combinedHatch);
            break;
	    }





        default:
            out_color = texture(textureImage, textureCoord);
            break;
    }
}
